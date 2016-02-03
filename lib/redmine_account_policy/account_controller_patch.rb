module RedmineAccountPolicy
	module Patches
		module AccountControllerPatch
			$invalid_credentials_cache = Hash.new

			def self.included(base)
				base.send(:include, DailyCronMethods)
				base.send(:include, InvalidCredentialsMethods)
			end

			module DailyCronMethods
				def run_account_policy_daily_tasks
					Rails.logger.info { "#{Time.now.utc}: Account Policy: Running daily tasks" }
					
					expire_old_passwords!             # password expiry
					lock_unused_accounts!             # lock unused accounts
					purge_expired_invalid_credentials # failed logins
					send_expiration_warnings          # expiration warnings	

					# TODO: doesn't persist to db; get's wipes out when save new password_lifetime
					Setting.plugin_redmine_account_policy.update({account_policy_checked_on: Date.today})
				end

				def already_ran_today?
					last_run = Setting.plugin_redmine_account_policy[:account_policy_checked_on]
					return false if last_run.nil?
					last_run == Date.today ? true : false
				end

				# enable must_change_passwd for all expired users.
				def expire_old_passwords!
					User.where(type: 'User', must_change_passwd: false).each do |user|
						user.update_attribute(:must_change_passwd, true) if user.password_expired?
						#send expiration notification email
						Mailer.notify_password_is_expired(user).deliver if user.password_expired? 
						
					end
				end
				
				def send_expiration_warnings
					#if Redmine 2.x, password_max_age doesn't exist, so use the setting in account policy. 
					#Otherwise, use Redmine core password_max_age
					password_max_age = (Setting.password_max_age.nil? || Setting.password_max_age.to_i.days==0) ? Setting.plugin_redmine_account_policy[:password_max_age].to_i.days : Setting.password_max_age.to_i.days  	 
#					password_max_age = Setting.password_max_age.to_i.days || Setting.plugin_redmine_account_policy[:password_max_age].to_i.days	
					expiration_warn_threshold = Setting.plugin_redmine_account_policy[:password_expiry_warn_days].to_i 
				
					#only run on unlocked users
					User.where(type: 'User', status: [User::STATUS_REGISTERED, User::STATUS_ACTIVE]).each do |user|
						
						#if the user's password is past the expiration warn threshold
						if (((((user.passwd_changed_on || user.created_on).to_date + password_max_age) - Date.today).to_i) < expiration_warn_threshold) 
							#send the expiration warning email unless their password has already expired
							send_warning_password_expiry_mail(user) unless user.password_expired?	
						end
					end
				end

				def lock_unused_accounts!
					User.where(type: 'User', status: [User::STATUS_REGISTERED, User::STATUS_ACTIVE]).each do |user|
						if user.account_unused?
							user.update_attribute(:must_change_passwd, true) if user.password_expired?
							user.lock!
						end
					end
				end

				#	This also clears any non-existent usernames/logins.
				#	Non-existent usernames are allowed to avoid exposing valid usernames
				#   (by having a different error message).
				def purge_expired_invalid_credentials
					seconds = Setting.plugin_redmine_account_policy[:account_lockout_duration].to_i.minutes

					#added brackets around conditional, seems to resolve issue thrown
					#where method 'round method of class nil:NilClass" is being called
					$invalid_credentials_cache.delete_if do |username, counter|
						(counter.is_a?(Time) && (counter + seconds) < Time.now.utc)
					end
				end


				def send_warning_password_expiry_mail(user)
					return unless Setting.plugin_redmine_account_policy[:password_expiry_warn_days].to_i > 0 

					Mailer.notify_password_warn_expiry(user).deliver unless user.nil?
				end
			end
		end
	end

	module InvalidCredentialsMethods
		def self.included(base)
			base.alias_method_chain :invalid_credentials, :account_policy
			base.alias_method_chain :password_authentication, :account_policy
			base.alias_method_chain :account_locked, :account_policy
			base.alias_method_chain :lost_password, :account_policy
		end

		def lost_password_with_account_policy
			lost_password_without_account_policy
			#on all post requests (whether user is nonexistent, locked, or otherwise),
			#redirect to signin_path
			if request.post?
				#if token param exists, this is an update password request, so
				#don't flash the lost password email confirmation
				unless params[:token]
					#if a redirection is already occurring, do not redirect again to avoid
					#DoubleRenderErrors -- only available in Rails 3.2+
					redirect_to signin_path unless performed?	
		 			flash[:notice] = l(:notice_account_lost_email_sent)
				end
			end
		end

		def account_locked_with_account_policy(user,redirect_path)
			#Check if user is locked AND in cache (implication: user was locked due to failed logins)
			#If so, flash lockout message instead of default user locked message
			counter = $invalid_credentials_cache[params[:username]] 
				
			if temporarily_locked_by_plugin?(user) || exists_in_cache_and_timed_out?(params[:username]) 
				flash_lockout(params[:username])
				return
			end
			account_locked_without_account_policy(user, signin_path)

		end
		
		def password_authentication_with_account_policy
			#adds logic before the basic password_authentication routine occurs
			#ensures that users can unlock themselves if they're in timeout
			#but cannot unlock themselves if they've been locked any other way
			user = User.try_to_login(params[:username], params[:password], false)
			user_from_login = User.where("login = ?", params[:username]).take
			@seconds = Setting.plugin_redmine_account_policy[:account_lockout_duration].to_i.minutes
			counter = $invalid_credentials_cache[params[:username]]
			
			#if the user is locked but not due to the plugin, delete them from the cache (this would only occur 
			#if the admin has locked the user intentionally, instead of the plugin doing it automatically)
			$invalid_credentials_cache.delete(params[:username]) if (is_locked?(user_from_login) && !temporarily_locked_by_plugin?(user_from_login)) 
				
			
			#allows users to activate themselves if they are present in the cache and
			#timeout is no longer in effect
			unless counter.nil? || user.nil? || timed_out?(user) #|| counter.is_a?(Fixnum)
				user.activate! if temporarily_locked_by_plugin?(user)
			end
			
			#if user is locked, and the lock is due to the plugin, skip the password_authentication routine and go 
			#straight to the account_locked method. Also, spoof this behaviour if the user does not actually
			#exist in the database, but should be 'locked out'
			if user_from_login && temporarily_locked_by_plugin?(user_from_login) && timed_out?(user_from_login) || (user_from_login.nil? && exists_in_cache_and_timed_out?(params[:username]))
				account_locked_with_account_policy(user_from_login,signin_path)
			else
				password_authentication_without_account_policy
			end

		end


		def invalid_credentials_with_account_policy
			username = params[:username].downcase
			lockout_duration = Setting.plugin_redmine_account_policy[:account_lockout_duration].to_i
			user_from_login = User.where("login = ?", params[:username]).take
			counter = $invalid_credentials_cache[username]

			#check if username is blank or account policy is diabled
			#also, if a user is *already locked*, but *not* because of failed logins (such that they are not in the
			#invalid credentials cache), don't enter them into the cache (otherwise they can unlock themselves by failing out and
			#entering the right password)
			if username.blank? || lockout_duration == 0 || (counter.nil? && is_locked?(user_from_login))
				#because code already exposes locked accounts, ensure that 'locked account' message is returned on *every attempt*
				#otherwise, attackers can determine passwords of locked accounts
				if (counter.nil? && is_locked?(user_from_login))
					redirect_to signin_path unless performed?
					flash[:error] = l(:notice_account_locked)
				else
				# pass username back to Redmine's default handler
				invalid_credentials_without_account_policy
				end
				# now let's deal with invalid passwords
			else
				if counter.nil?
					# first failed attempt
					warn_failure(username, 1)

					# user already failed
				elsif counter.is_a?(Time)
					if counter + @seconds > Time.now.utc && is_locked?(user_from_login)
						warn_lockout_in_effect(username)
					else
						# lockout expired, and login failed again
						# unlock the user here so that the user's updated_on
						# can be correctly updated in the case that the user fails out again
						warn_failure(username, 1)
						user_from_login.activate! if user_from_login
					end
				else
					if is_locked?(user_from_login) && !temporarily_locked_by_plugin?(user_from_login)
						#handles the case in which the user has been locked while
						#in the cache - delete them from the cache and redirect them to the locked page
						$invalid_credentials_cache.delete(username)
						account_locked_with_account_policy(user_from_login,signin_path)

					else
						# is counter, not a Time
						counter += 1
						if counter >= Setting.plugin_redmine_account_policy[:account_lockout_threshold].to_i
							user_from_login.lock! if user_from_login
							warn_lockout_starts(username)
						else
							warn_failure(username, counter)
						end
					end
				end
			end
		end
		
		def account_locked_with_account_policy(user,redirect_path)
			#Check if user is locked AND in cache (implication: user was locked due to failed logins)
			#If so, flash lockout message instead of default user locked message
			counter = $invalid_credentials_cache[params[:username]] 
				
			if temporarily_locked_by_plugin?(user) || exists_in_cache_and_timed_out?(params[:username]) 
				flash_lockout(params[:username])
				return
			end
			account_locked_without_account_policy(user, signin_path)

		end
		
		def exists_in_cache_and_timed_out?(username)
			counter = $invalid_credentials_cache[params[:username]] 
			counter_exists_and_is_time?(counter) && ((counter + @seconds) > Time.now.utc)

		end

		def timed_out?(user)
			counter = $invalid_credentials_cache[user.login.downcase] unless user.nil?
			counter_exists_and_is_time?(counter) && ((counter + @seconds) > Time.now.utc)
		end
		
		def counter_exists_and_is_time?(counter)
			counter && counter.is_a?(Time)			
		end
		

		def temporarily_locked_by_plugin?(user)
			#if user is locked, they're in timeout, and the lock was due to the timeout, return true. Else, return false
			counter = $invalid_credentials_cache[user.login.downcase] unless user.nil?
			return (is_locked?(user) && counter_exists_and_is_time?(counter) && counter == user.updated_on)
		end
		
		def is_locked?(user)
			#if user exists and is locked, return true, else false
			user && user.locked?
		end

		private

		def warn_failure(username, counter)
			$invalid_credentials_cache[username] = counter
			flash_failure(counter)
			send_failure_mail(username)
			write_log(username, 'Failed login due to invalid password.')
		end

		def warn_lockout_starts(username)
			user_from_login = User.where("login = ?", username).take
			
			$invalid_credentials_cache[username] = user_from_login.nil? ? Time.now.utc : user_from_login.updated_on

			flash_lockout(username)

			send_lockout_mail(username)

			write_log(username, 'Login failed - lockout starts.')
		end

		def warn_lockout_in_effect(username)
			flash_lockout(username)

			write_log(username, 'Failed login due to temporary lockout.')
		end

		def flash_failure(counter)
			flash.now[:error] = "#{l(:notice_account_invalid_creditentials)}."                       \
				" #{Setting.plugin_redmine_account_policy[:account_lockout_threshold].to_i - counter}" \
				" #{l(:rap_notice_invalid_logins_remaining)}"
		end

		def flash_lockout(username)
			minutes = ((($invalid_credentials_cache[username] + @seconds) - Time.now.utc) / 60).to_i
			flash.now[:error] = "#{l(:rap_notice_account_lockout)}" \
				" #{l('datetime.distance_in_words.x_minutes', count: minutes)}."
		end

		def send_failure_mail(username)
			return unless Setting.plugin_redmine_account_policy[:notify_on_failure] == 'on'

			user = User.find_by_login(username)
			Mailer.notify_login_failure(user, request.remote_ip).deliver unless user.nil?
		end

		def send_lockout_mail(username)
			user = User.find_by_login(username)
			Mailer.notify_account_lockout(user, request.remote_ip).deliver unless user.nil?
		end

		def is_user?(username)
			user = User.find_by_login(username)
			user
		end

		def write_log(username, log_message)
			log_message << " (#{$invalid_credentials_cache[username]}) for '#{params[:username]}'" \
				"from #{request.remote_ip} at #{Time.now.utc}"
			logger.warn { log_message }
		end
	end
end

AccountController.send :include, RedmineAccountPolicy::Patches::AccountControllerPatch
