module RedminePasswordPolicy
	module Patches
		module MyControllerPatch

			def self.included(base)
				base.send(:include, InstanceMethods)

				# Wrap the methods we are extending
				base.alias_method_chain :password, :policy
			end

			module InstanceMethods
				def password_with_policy
					# run super first as it does other checks
					password_without_policy

					if request.get? && @user.password_expired?
						flash.now[:error] = l(:rpp_notice_password_expired)
					end
				end
			end

		end
	end
end

MyController.send :include, RedminePasswordPolicy::Patches::MyControllerPatch


