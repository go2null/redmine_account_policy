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
					$invalid_credentials_cache.delete_if do |username, counter|
						counter.is_a?(Time) && counter < Time.now.utc
					end
				end
			end
		end
	end

	module InvalidCredentialsMethods
		def self.included(base)
			base.alias_method_chain :invalid_credentials, :account_policy
			base.alias_method_chain :lost_password, :account_policy
		end

		def lost_password_with_account_policy
			#assigning method call to a placeholder variable so internal 'return' statements 
			#do not stop method execution
			placeholder_does_not_matter = lost_password_without_account_policy
          		
			#on all post requests (whether user is nonexistent, locked, or otherwise),
			#redirect to signin_path
			if request.post?
				#if a redirection is already occurring, do not redirect again to avoid
				#DoubleRenderErrors -- only available in Rails 3.2+
				redirect_to signin_path unless performed?	
		 		flash[:notice] = l(:notice_account_lost_email_sent)
			end
		end

		def invalid_credentials_with_account_policy
			username = params[:username].downcase
			lockout_duration = Setting.plugin_redmine_account_policy[:account_lockout_duration].to_i

			if username.blank? || lockout_duration == 0
				# pass username back to Redmine's default handler
				invalid_credentials_without_account_policy

				# now let's deal with invalid passwords
			else
				counter = $invalid_credentials_cache[username]
				if counter.nil?
					# first failed attempt
					warn_failure(username, 1)

					# user already failed
				elsif counter.is_a?(Time)
					if counter > Time.now.utc
						warn_lockout_in_effect(username)
					else
						# lockout expired, and login failed again
						warn_failure(username, 1)
					end
				else
					# is counter, not a Time
					counter += 1
					if counter >= Setting.plugin_redmine_account_policy[:account_lockout_threshold].to_i
						warn_lockout_starts(username)
					else
						warn_failure(username, counter)
					end
				end
			end
		end

		private

		def warn_failure(username, counter)
			$invalid_credentials_cache[username] = counter
			flash_failure(counter)
			send_failure_mail(username)
			write_log(username, 'Failed login due to invalid password.')
		end

		def warn_lockout_starts(username)
			seconds = Setting.plugin_redmine_account_policy[:account_lockout_duration].to_i.minutes
			$invalid_credentials_cache[username] = Time.now.utc + seconds

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
			minutes = (($invalid_credentials_cache[username] - Time.now.utc) / 60).to_i
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
