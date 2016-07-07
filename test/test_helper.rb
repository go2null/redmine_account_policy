# Load the Redmine helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

module TestSetupMethods
  # reset all settings
  def reset_settings
    Setting.plugin_redmine_account_policy.update({password_complexity: 0})
    Setting.plugin_redmine_account_policy.update({password_max_age: 0})
    Setting.plugin_redmine_account_policy.update({password_min_unique: 0})
    Setting.plugin_redmine_account_policy.update({password_min_unique: 0})
    Setting.plugin_redmine_account_policy.update({password_min_age: 0})
    Setting.plugin_redmine_account_policy.update({account_lockout_duration: 0})
    Setting.plugin_redmine_account_policy.update({account_lockout_threshold: 0})
    Setting.plugin_redmine_account_policy.update({notify_on_failure: 0})
    Setting.plugin_redmine_account_policy.update({notify_on_lockout: 0})
    Setting.plugin_redmine_account_policy.update({unused_account_max_age: 0})
    Setting.plugin_redmine_account_policy.update({account_policy_checked_on: nil })
  end

  def create_user(login, pwd, email)
    mock_user = User.create() do |u|
      u.login                 = login
      u.password              = pwd
      u.password_confirmation = pwd
      u.firstname             = login
      u.lastname              = 'doe'
      u.mail                  = email
      u.language              = 'en'
      u.mail_notification     = 'only_my_events'
      u.must_change_passwd    = false
      u.parent_id             = 1 if u.respond_to?(:parent_id=) # check for my_users
      u.status                = 1
      u.auth_source_id        = nil
    end
    # block below prints out all errors if validation fails
    if mock_user.errors.any?
      mock_user.errors.each do |attribute, message|
        puts "Error - #{attribute} : #{message}"
      end
    end
    mock_user
  end

  # creates a mock user
  def create_mock_user(login = 'alice',
                       pwd = repeat_str('1234567890'),
                       email = 'alice@doe.com')
    @mock_user = create_user(login, pwd, email)
    @mock_user
  end

  # retrieves the mock user from the database
  def mock_user
    User.find_by_login(@mock_user.login)
  end
end


module TestDailyMethods
  include TestSetupMethods

  def reset_daily_cron
    Setting.plugin_redmine_account_policy.update({account_policy_checked_on: nil})
  end

  # runs whatever task the plugin uses to lock expired users
  def run_daily_cron
    @mock_bob_login = 'bob'
    @mock_bob_password = '1234567890'

    if User.find_by_login(@mock_bob_login).nil?
      @bob = create_user(@mock_bob_login, @mock_bob_password, 'bob@doe.com')
    end

    post(:login, {
      :username => @mock_bob_login,
      :password => @mock_bob_password})
    assert_redirected_to my_page_path,
      "Should have been able to login"
  end

  def run_daily_cron_with_reset
    reset_daily_cron
    run_daily_cron
  end
end

module TestHelperMethods
  # returns when the user corresponding to the given login
  # last changed their password
  def get_pwd_change_date(login)
    mock_user.passwd_changed_on
  end

  # creates a new password given a pattern and a length requirement
  def repeat_str(input, length = Setting.password_min_length)
    puts input if @show_debug
    repeated_input = ""
    while repeated_input.length < length.to_i
      repeated_input << input
    end
    repeated_input
  end

  # logs in, sets up session params to allow password changes
  def attempt_login(password)
    @account_controller = AccountController.new
    @current_controller = @controller
    # switches controller to account controller to allow login
    @controller = @account_controller
    # post login
    post(:login, {
      :username => @mock_user.login,
      :password => password})
    # successful login results in redirect to my_page
    assert_redirected_to my_page_path, 'Check login success'
    # catches any error flashes
    print_flashes
    # sets controller back to my_controller
    @controller = @current_controller
    reset_settings
  end

  # tries to change the password to a new one
  def try_to_change_password_to(new_password)
    post(:password,{
      :password => @mock_user.password,
      :new_password => new_password,
      :new_password_confirmation => new_password})
    print_flashes
  end

  # posts bad logins until just before the threshold
  def make_bad_login_attempts_until_one_before(attempts)
    (1..(attempts-1)).each do
      post(:login, {
        :username => @mock_user.login,
        :password => 'adkf'})
    end
  end

  # prints all flashes if errors and if show flashes is true
  def print_flashes
    if flash[:error] && @show_flashes
      flash.each do |key, value|
        puts "Flash - #{key} : #{value}"
      end
    end
  end
end

module TestMailerMethods
  # returns a string array of all to, bcc, and cc recipients in
  # the mail deliveries
  def all_mail_recipients
    recipients = Array.new

    ActionMailer::Base.deliveries.each do |mail|
      mail.to.each do |to|
        recipients << to.to_s
      end
      mail.cc.each do |cc|
        recipients << cc.to_s
      end
      mail.bcc.each do |bcc|
        recipients << bcc.to_s
      end
    end

    recipients
  end

  def parent_exists?
    ActiveRecord::Base.connection.column_exists?(:users, :parent_id)
  end

  # returns an array of all the recipients of an input mail
  def mail_recipients(mail)
    all_recipients = Array.new
    mail.to.each do |to|
      all_recipients << to.to_s
    end
    mail.cc.each do |cc|
      all_recipients << cc.to_s
    end
    mail.bcc.each do |bcc|
      all_recipients << bcc.to_s
    end
    all_recipients
  end

  # check if input recipients are in the input mail
  def are_recipients_correct?(users, mail)
    @user_diff = users.sort.uniq - mail_recipients(mail).sort.uniq
    assert @user_diff.empty?,
      "Recipients #{@user_diff.to_s} should be in mail: #{mail.subject}"
  end

  # setting mailer variables for testing
  def set_mailer_test_variables
    # sets delivery method to test mode so email is not really sent
    ActionMailer::Base.delivery_method = :test
    # ensures mail will be sent using the ActionMailer
    ActionMailer::Base.perform_deliveries = true
    # clears the existing delivery array
    ActionMailer::Base.deliveries = []
  end
end
