require File.expand_path('../../test_helper', __FILE__)

require File.expand_path('../../../lib/redmine_account_policy/account_controller_patch', __FILE__)

class AccountControllerTest < ActionController::TestCase
include RedmineAccountPolicy

	def test_already_ran_today?
		Setting.plugin_redmine_account_policy.update({account_policy_checked_on: Date.today})
		assert RedmineAccountPolicy::Patches::AccountControllerPatch::DailyCronMethods.already_ran_today?
		Setting.plugin_redmine_account_policy.update({account_policy_checked_on: nil})
		assert !RedmineAccountPolicy::Patches::AccountControllerPatch::DailyCronMethods.already_ran_today?
	end
		

end
