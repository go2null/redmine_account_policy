module RedmineAccountPolicy
	module Patches
		module AccountControllerPatch

			def self.included(base)
				base.send(:include, InstanceMethods)
					base.alias_method_chain :password_authentication, :user_from_login
			end

			module InstanceMethods
				#TODO: Commented out include in controller_account_success_authentication_after_hook.rb
				def password_authentication_with_user_from_login
						user = User.try_to_login(params[:username], params[:password], false)
						user_from_login = User.where("login = ?", params[:username])
						puts user_from_login

						if user_from_login.nil?
							invalid_credentials
						elsif user.nil?
							if Setting.plugin_redmine_account_policy[:fails_log].has_key?(user_from_login.id)
								fails_log_value = Setting.plugin_redmine_account_policy[:fails_log].fetch(user_from_login.id)
								if fails_log_value.is_a? Integer
								@settings[:fails_log].[user_from_login.id] = fails_log_value + 1
									if Setting.plugin_redmine_account_policy[:fails_log].fetch(user_from_login.id) > 6
										@settings[:fails_log].[user_from_login.id] = DateTime.UtcNow + Setting.plugin_redmine_account_policy[:user_timeout_in_minutes].minutes
									end
								elsif fails_log_value.is_a? DateTime
									if DateTime.UtcNow > se
								end
							end
						end

						if user.nil?
								invalid_credentials
						elsif user.new_record?
								onthefly_creation_failed(user, {:login => user.login, :auth_source_id => user.auth_source_id })
						else
								# Valid user
							if user.active?
								successful_authentication(user)
							else
								handle_inactive_user(user)
							end
						end
						password_authentication_without_user_from_login
				end

				def run_account_policy_daily_tasks
					expire_old_passwords!
					lock_unused_accounts!

					# TODO: doesn't persist to db; get's wipes out when save new password_lifetime
					Setting.plugin_redmine_account_policy.update({account_policy_checked_on: Date.today})
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
			end

		end
	end
end

AccountController.send :include, RedmineAccountPolicy::Patches::AccountControllerPatch
