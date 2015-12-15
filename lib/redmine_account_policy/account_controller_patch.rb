module RedmineAccountPolicy
	module Patches
		module AccountControllerPatch
			$fails_log = Hash.new

			def self.included(base)
				base.send(:include, InstanceMethods)
				base.send(:include, ClassMethods)
			end

			module InstanceMethods

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

			module ClassMethods

				def self.included(base)
					base.alias_method_chain :invalid_credentials, :lockout_error
				end

				def invalid_credentials_with_lockout_error
					user_from_login = User.where("login = ?", params[:username]).take
					RedmineAccountPolicyMailer.on_each_fail_notification(user_from_login)
					if $fails_log.has_key?(user_from_login.id)
						fails_log_value = $fails_log.fetch(user_from_login.id)
						if fails_log_value.class.to_s.eql? "DateTime"
							if fails_log_value > DateTime.now.utc
								logger.warn "Failed login due to timeout lock for '#{params[:username]}' from #{request.remote_ip} at #{Time.now.utc}"
								flash.now[:error] = l(:rpp_notice_account_timeout) \
																		+ ((fails_log_value - DateTime.now.utc) * 1.days / 60).ceil.to_s \
																		+ " " + l(:rpp_setting_minute_plural) \
																		+ " or contact an administrator."
							end
						else
							logger.warn "Failed login for '#{params[:username]}' from #{request.remote_ip} at #{Time.now.utc}"
							flash.now[:error] = l(:notice_account_invalid_creditentials) \
																	+ ". " \
																	+ (Setting.plugin_redmine_account_policy[:max_login_fails].to_i \
																		- fails_log_value).to_s + " attempts remaining."
						end
					else
							invalid_credentials_without_lockout_error
					end
				end

			end
		end
	end
end

AccountController.send :include, RedmineAccountPolicy::Patches::AccountControllerPatch
