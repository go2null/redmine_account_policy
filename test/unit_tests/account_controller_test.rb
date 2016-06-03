require File.expand_path('../../test_helper', __FILE__)

require File.expand_path('../../../lib/redmine_account_policy/account_controller_patch', __FILE__)

class AccountControllerTest < ActionController::TestCase
  include RedmineAccountPolicy

  def setup
    @a = AccountController.new
    @a.extend(RedmineAccountPolicy::Patches::AccountControllerPatch::DailyCronMethods)
    @a.extend(RedmineAccountPolicy::InvalidCredentialsMethods)
    #	@a.extend(ActionController::TestCase::Behavior)
    @a.instance_eval('@seconds = 10.minutes')

    $invalid_credentials_cache = Hash.new

    @input_username = 'test_user' 
  end

  test "already_ran_today?" do
    Setting.plugin_redmine_account_policy.update({account_policy_checked_on: Date.today})
    assert @a.already_ran_today?, 'Has already run today'
    Setting.plugin_redmine_account_policy.update({account_policy_checked_on: nil})
    assert !@a.already_ran_today?, 'No previous run stored'
  end

  test "counter_exists_and_is_time?" do
    assert @a.counter_exists_and_is_time?(Time.now.utc), 'Time passes'
    assert !@a.counter_exists_and_is_time?(nil), 'Nil doesnt pass'
  end

end
