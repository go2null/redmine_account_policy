module RedminePasswordPolicy
	module Patches
		module MyControllerPatch

			def self.included(base)
				base.send(:include, InstanceMethods)

				# Wrap the methods we are extending
				base.alias_method_chain :password, :account_policy
			end

			module InstanceMethods
				def password_with_account_policy
					# run first as it does other checks
					password_without_account_policy

					if request.get? && @user.password_expired?
						flash.now[:error] = l(:rap_notice_password_expired)
					end
				end
			end

		end
	end
end

MyController.send :include, RedminePasswordPolicy::Patches::MyControllerPatch


