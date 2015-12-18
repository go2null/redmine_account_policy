module RedmineAccountPolicy
	module Hooks
		class ControllerAccountSuccessAuthenticationAfter  < Redmine::Hook::ViewListener

			include RedmineAccountPolicy::Patches::AccountControllerPatch::DailyCronMethods
			def controller_account_success_authentication_after(context={})
				# reset failed login attempts for current user
				$invalid_credentials_cache.delete(User.current.login.downcase)

				# use this hook to create a pseudo daily cron
				run_account_policy_daily_tasks unless already_ran_today?
			end

		end
	end
end
