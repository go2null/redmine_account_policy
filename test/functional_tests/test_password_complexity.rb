require File.expand_path('../../test_helper', __FILE__)


class MyControllerTest < ActionController::TestCase
  include TestHelperMethods
  include TestSetupMethods
  include PluginSettingsMethods

  def setup
    # turn off all account policy settings
    reset_settings

    @show_flashes = false
    @show_debug = false

    @alice = create_mock_user

    @test_input_array = ['b','1','$','B','aA','a1','a$','1$','1A','A$','aA1','A1$','1$a','$aA','aA1$']

    @min_len = 20
    Setting.password_min_length = @min_len
  end

  # tests password complexity requirements (# of character spaces)	
  test "all_password_complexity_tiers_if_setting_on" do
    attempt_login(@alice.password)	
    # run 'password is sufficiently complex' tests
    pass_complexity_tests_for_inputs(@test_input_array, true)
    # run 'password is insufficiently complex' tests
    pass_complexity_tests_for_inputs(@test_input_array, false)
  end

  # tests that there are no password complexity requirements if setting off	
  test "no_password_complexity_restrictions_if_setting_off" do
    attempt_login(@alice.password)	
    # run 'password is sufficiently complex' for complexity = 0
    pass_complexity_tests_for_inputs(@test_input_array, true, 0)
  end

  # wrapper for pass and fail test cases for all complexities (by default)
  # or for a specific complexity
  def pass_complexity_tests_for_inputs(input, pass, complexity = nil)
    input.each do |chars|
      @test_new_password = repeat_str(chars, @min_len)
      if pass
        pass_test_for_setting(complexity || chars.length) 
      else
        fail_test_for_setting(complexity || chars.length + 1)
      end
    end
  end

  def pass_test_for_setting(int)
    set_plugin_setting(:password_complexity, int)

    try_to_change_password_to(@test_new_password)
    assert_redirected_to my_account_path,
      "Should succeed on complexity #{int.to_s}"
    @alice.password = @test_new_password
    puts @alice.password if @show_debug
  end

  def fail_test_for_setting(int)
    set_plugin_setting(:password_complexity, int)

    try_to_change_password_to(@test_new_password)
    assert_response :success,
      "Should fail on complexity #{int.to_s}"
  end
end
