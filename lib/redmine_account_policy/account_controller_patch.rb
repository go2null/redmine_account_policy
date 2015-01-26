module RedmineAccountPolicy
	module Patches
		module AccountControllerPatch

			def self.included(base)
				base.send(:include, InstanceMethods)
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

		end
	end
end

AccountController.send :include, RedmineAccountPolicy::Patches::AccountControllerPatch

