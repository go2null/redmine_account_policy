module RedminePasswordPolicy
  module Patches
    module MyControllerPatch

      def self.included(base)
        base.send(:include, InstanceMethods)

        #  Wrap the methods we are extending
        base.alias_method :password_without_account_policy, :password
        base.alias_method :password, :password_with_account_policy
      end

      module InstanceMethods
        DLMTR = ':'
        TRUNCATE_BY_N = 3

        def password_with_account_policy
          # set minimum unique passwords and user
          @min_uniques = Setting
          .plugin_redmine_account_policy['password_min_unique']
          .to_i	

          @user = User.current
          # if user cannot change password, then redirect
          unless @user.change_password_allowed?
            flash[:error] = l(:notice_can_t_change_password)
            redirect_to my_account_path
            return
          end

          # add current password to old passwords cache
          if @min_uniques > 1
            store_and_clear_old_fields(@user.hashed_password, @user.salt)
          end
          # remove any passwords old enough to be reused
          # clear_excess_old_hashed_passwords if @min_uniques > 1

          #  only catch if password *would* be set and 
          #  user has enabled minimum uniques feature
          #  otherwise default to core behaviour
          if request.post? && new_password_okay? && @min_uniques > 1
            # if its a password that has been reused before,
            # flash error and return	
            if is_an_old_hashed_password?(params[:new_password])
              flash.now[:error] = l(:rap_notice_password_reuse, 
                                    min_unique: @min_uniques)			
              return
            else
              password_without_account_policy
            end
          else
            password_without_account_policy
          end

          if request.get? && @user.password_expired?
            flash.now[:error] = l(:rap_notice_password_expired)
          end
        end

        # store current password and current salt
        # clear old_ fields if necessary
        def store_and_clear_old_fields(password, salt)
          store_old_hashed_password(password)
          store_old_salt(salt)
          clear_excess_old_hashed_passwords
          clear_excess_old_salts
        end

        # stores hashed password
        def store_old_hashed_password(password)
          if db_user_old_pwds.nil?
            get_db_user.update_attribute(:old_hashed_passwords, truncate(password) + DLMTR) 
          else
            if (/#{truncate(password)}/ =~ db_user_old_pwds).nil?
              get_db_user.update_attribute(:old_hashed_passwords, db_user_old_pwds << truncate(password) + DLMTR) 
            end
          end
        end

        # truncates input password hashes so passwords are not revealed
        # even if all password hashes are compromised
        def truncate(hashed_input, truncate_amount = TRUNCATE_BY_N)
          return if hashed_input.nil?
          # final character in string is at length - 1, so to truncate
          # by n, must set range to truncate amount - 1
          hashed_input[0..hashed_input.length - truncate_amount - 1]
        end

        # returns the current user's old hashed passwords
        # from the database
        def db_user_old_pwds
          get_db_user.old_hashed_passwords
        end

        # returns persistent user object of the current user
        def get_db_user
          User.find_by_login(@user.login)
        end

        # stores hashed salt (with extra randomized salts)
        def store_old_salt(salt)
          if get_db_user.old_salts.nil?
            get_db_user
            .update_attribute(:old_salts, random_salts_string(salt)) 
          else
            if (/#{salt}/ =~ @user.old_salts).nil?

              appended_salts = @user.old_salts << random_salts_string(salt)

              get_db_user.update_attribute(:old_salts, appended_salts)

            end
          end
        end

        # clear out passwords that can be reused
        def clear_excess_old_hashed_passwords
          user_old_hash_pwds = db_user_old_pwds 
          return if user_old_hash_pwds.nil?

          # first, find the size of a hashed password
          # using a placeholder password
          # Password hash length  is 40 for SHA1, 
          # but hopefully Redmine changes their implementation
          size_of_hash_pwds = truncate(User.hash_password('0')).length

          # max # of passwords is a function of the number of 
          # uniques required by the character length of a 
          # hashed password. As we are adding single delimiters 
          # per new password added, the final max size is 
          # the character length of the passwords
          # plus the number of unique passwords
          max_size = (@min_uniques * (size_of_hash_pwds + 1)) \

            if user_old_hash_pwds.length > max_size
              # remove passwords until the length 
              # is less than the maximum size
              user_old_hash_pwds = user_old_hash_pwds.split(//).last(max_size).join
          end

          get_db_user.update_attribute(:old_hashed_passwords, user_old_hash_pwds)
        end


        # clear out old salts that no longer map to a password
        def clear_excess_old_salts
          user_old_salts = get_db_user.old_salts 
          return if user_old_salts.nil?

          # first, find the size of a salt
          size_of_salts = User.generate_salt.length
          double_uniques = @min_uniques * 2

          # max size is equal to the maximum number 
          # of salts generated on store, which is double the 
          # number of min_uniques multiplied by the size of the salts
          # plus one (to account for delimiters) 
          # multiplied by the total number of min_uniques
          max_size = ((double_uniques) * (size_of_salts + 1)) * @min_uniques

          if user_old_salts.length > max_size
            # remove salts until the length is 
            # less than the maximum size
            user_old_salts = user_old_salts.split(//).last(max_size).join
          end

          get_db_user.update_attribute(:old_salts, user_old_salts)
        end

        def is_an_old_hashed_password?(password)
          return false if min_uniques_disabled_or_no_pwds_stored?
          !possible_hashes(password).intersection(stored_pwds).empty?
        end

        def min_uniques_disabled_or_no_pwds_stored?
          @min_uniques == 1 || db_user_old_pwds.nil?
        end

        def stored_pwds
          db_user_old_pwds.split(DLMTR).to_set
        end

        # hashes input password with all hashes
        # then returns unique set of hashes
        def possible_hashes(password)
          hashes_array = Array.new
          old_salts_array = get_db_user.old_salts.split(DLMTR)
          old_salts_array.each do |salt|
            hashes_array << truncate(multistep_pwd_hash(password, salt))
          end
          hashes_array.to_set
        end

        # check that password matches confirmation and is not blank
        def new_password_okay?
          ((params[:new_password] == params[:new_password_confirmation]) && !params[:new_password].blank?)
        end

        # hash password given a salt
        # in Redmine style (multiple hash with salt)
        def multistep_pwd_hash(input_password, input_salt)
          # passwords are processed in two steps - 
          # first, the cleartext password is hashed
          # then, the user's unique salt is prepended to the string
          # then, the password is hashed again.
          # This matches Redmine default behaviour
          first_hash = User.hash_password(input_password)
          User.hash_password("#{input_salt}#{first_hash}")
        end

        # takes in a real salt and creates a number of dummy salts
        # shuffles the order of the salts, then outputs a delimitered
        # string of the salt and salts generated
        def random_salts_string(salt, n = @min_uniques)
          number_of_salts = @min_uniques + rand(0..n)
          salts_array = Array.new
          salts_array << salt
          (1..number_of_salts).each do
            salts_array << User.generate_salt
          end
          salts_array.shuffle.join(DLMTR) + DLMTR
        end


      end

    end
  end

end
MyController.send :include, RedminePasswordPolicy::Patches::MyControllerPatch


