module RedmineAccountPolicy
	module Patches
		module UserPatch

			def self.included(base)
				base.send(:include, InstanceMethods)
			end

			module InstanceMethods
				# TODO: should be in, for example, an ApplicationPatch module
				def password_max_age
					Setting.plugin_redmine_account_policy[:password_max_age].to_i
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def password_expiry_policy_enabled?
					password_max_age > 0
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def unused_account_max_age
					Setting.plugin_redmine_account_policy[:unused_account_max_age].to_i
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def unused_account_policy_enabled?
					unused_account_max_age > 0
				end


				# Can only be expired if lifetime is set and is not 0.
				def password_expired?
					# only expired if password_max_age set, and > 0
					return false unless password_expiry_policy_enabled?

					(passwd_changed_on || created_on).to_date + password_max_age <= Date.today
				end

				# TODO: prefered to override 'must_change_password?' and use super
				# but it doesn't work
				#def must_change_password_with_policy?
				#	if password_expired?
				#self.must_change_passwd = true
				#error.add 'expired!'
				#	end

				#	must_change_password_without_policy?
				#end

				def account_unused?
					return false unless unused_account_policy_enabled?

					(last_login_on || created_on).to_date + unused_account_max_age <= Date.today
				end
			end

		end
	end
end

User.send(:include, RedmineAccountPolicy::Patches::UserPatch)
