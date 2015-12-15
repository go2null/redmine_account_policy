module RedmineAccountPolicy
	module Hooks
		class ControllerAccountSuccessAuthenticationAfter  < Redmine::Hook::ViewListener

			 include RedmineAccountPolicy::Patches::AccountControllerPatch::InstanceMethods
			def controller_account_success_authentication_after(context={})
				# as we don't have a daily cron, trigger on admin login
				run_account_policy_daily_tasks if User.current.admin?
			end

		end
	end
end
