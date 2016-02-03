module RedminePasswordPolicy
	module Patches
		module MyControllerPatch

			def self.included(base)
				base.send(:include, InstanceMethods)

				# Wrap the methods we are extending
				base.alias_method_chain :password, :account_policy
			end

			module InstanceMethods
				def is_an_old_password?(password)
					return false unless @min_uniques > 1
					return !(/#{password}/ =~ @user.old_passwords).nil?
				end
									
				def add_to_old_passwords(password)
					@user.old_passwords = password if @user.old_passwords.nil?
					@user.old_passwords << password if (/#{password}/ =~ @user.old_passwords).nil? 
				end
				
				def clear_excess_old_passwords
					#clear out passwords that may be reused
					
					#first, find the size of a hashed password, just using a placeholder password
					#password hash is 40 for SHA1, but hopefully Redmine changes their implementation)
					size_of_hashed_passwords = User.hash_password("0").length
					#max # of passwords is a function of the number of uniques required by the 
					#character length of a hashjed password
					while @user.old_passwords.length > (@min_uniques * size_of_hashed_passwords)
						#remove passwords until the length is less than the maximum size
                                                @user.old_passwords.slice!(0, size_of_hashed_passwords)
					end
				end

				def new_password_okay?
					#check that password matches confirmation and is not blank
					return ((params[:new_password] == params[:new_password_confirmation]) && !params[:new_password].blank?)
				end
					
				def multistep_password_hash(input_password)
					#passwords are processed in two steps - first, the cleartext password is hashed
					#then, the user's unique salt is prepended to the string
					#then, the password is hashed again - this matches Redmine default behaviour
					first_hash = User.hash_password(input_password)
					user_salt = @user.salt
					User.hash_password("#{user_salt}#{first_hash}")
				end

				def password_with_account_policy
					#set minimum unique passwords and user
					@min_uniques = Setting.plugin_redmine_account_policy[:password_min_unique].to_i	
					@user = User.current
					#if user cannot change password, then redirect
    					unless @user.change_password_allowed?
					      flash[:error] = l(:notice_can_t_change_password)
					      redirect_to my_account_path
					      return
				    	end
					
					#add current password to old passwords cache
					add_to_old_passwords(@user.hashed_password) if @min_uniques > 1
					#remove any passwords old enough to be reused
					clear_excess_old_passwords if @min_uniques > 1

					# only catch if password *would* be set and user has enabled minimum uniques feature
					# otherwise default to core behaviour
				    	if request.post? && new_password_okay? && @min_uniques > 1
						#if its a password that has been reused before, flash error and return	
						if is_an_old_password?(multistep_password_hash(params[:new_password]))
							flash.now[:error] = l(:rap_notice_password_reuse, min_unique: @min_uniques)			
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
			end

		end
	end

end
	MyController.send :include, RedminePasswordPolicy::Patches::MyControllerPatch


