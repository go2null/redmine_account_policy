require File.expand_path('../../test_helper', __FILE__)

class MyControllerTest < ActionController::TestCase

  include TestSetupMethods
  include TestHelperMethods
  include PluginSettingsMethods

  def setup
    # turn off all account policy settings
    reset_settings

    @show_flashes = false
    @show_debug = false

    @alice = create_mock_user
    # create account controller and my controller variables to allow
    # logins and password changes
    @account_controller = AccountController.new
    @my_controller = @controller
  end


  # tests that old passwords cannot be reused until 
  # enough unique passwords have been used
  test "cannot_reuse_old_passwords_within_limit_if_setting_on" do
    @min_len = 20
    Setting.password_min_length = @min_len

    attempt_login(@alice.password)	

    set_plugin_setting(:password_min_unique, 15)

    num_uniques = Setting.plugin_redmine_account_policy[:password_min_unique].to_i

    # change password num_uniques times
    loop_successful_password_changes(num_uniques)

    # attempt to reuse all the passwords just used
    loop_fail_password_changes(num_uniques)

    # change the password one more time (opening up the very first password
    # change for reuse)
    successfully_change_password_to(num_uniques + 1)

    # because first password is now open, successive changes
    # will open up the next password in the loop,
    # so verify that this behavior is true such that
    # all the old passwords can indeed be reused if changed in 
    # the correct order
    loop_successful_password_changes(num_uniques)
  end


  # tests that the last password cannot be reused if the setting is off (core behaviour)
  test "cannot_reuse_last_password_if_setting_off" do
    @min_len = 20
    Setting.password_min_length = @min_len

    attempt_login(@alice.password)	

    set_plugin_setting(:password_min_unique, 1)

    @number_pw_changes = 10

    # change password some number of times
    loop_successful_password_changes(@number_pw_changes)

    # verify that cannot change password to most recent password
    fail_to_change_password_to(@number_pw_changes)

    # successfully attempt to reuse all the passwords just used
    loop_successful_password_changes(@number_pw_changes)

    mock_user.update_attribute(:old_hashed_passwords, nil)
    mock_user.update_attribute(:old_salts, nil)

  end

  def loop_fail_password_changes(times)
    (1..times).each do |i|
      fail_to_change_password_to(i)
    end
  end

  def loop_successful_password_changes(times)
    (1..times).each do |i|
      successfully_change_password_to(i)
    end
  end

  def successfully_change_password_to(input)
    @new_password = repeat_str("a#{input.to_s}", @min_len)
    try_to_change_password_to(@new_password)
    assert_redirected_to my_account_path,
      "Should change password successfully : #{input.to_s} - #{@alice.inspect}"
    @alice.password = @new_password
  end

  def fail_to_change_password_to(input)
    @new_password = repeat_str("a#{input.to_s}", @min_len)
    try_to_change_password_to(@new_password)
    assert_response :success, 
      "Password change should fail reused-password : #{input.to_s} - #{@alice.inspect}"
  end
end
