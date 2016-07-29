require File.expand_path('../../test_helper', __FILE__)

class AccountControllerTest < ActionController::TestCase
  include TestSetupMethods
  include TestDailyMethods
  include TestHelperMethods
  include TestMailerMethods
  include PluginSettingsMethods

  def setup
    set_mailer_test_variables
    # turn off all account policy settings
    reset_settings

    @alice = create_mock_user

    Setting.password_max_age = 90

    @cron_repeats = 100
  end


  # tests password expiry feature - expire passwords if past expiration age
  test "password_should_expire_if_past_expiration_age" do
    mock_user.update_column(:passwd_changed_on, pwd_date_if_now_expired - 1.days)

    run_daily_cron_with_reset

    assert mock_user.must_change_passwd?,
      "Should have must_change_passwd set to true #{mock_user.inspect}"
  end


  # tests that repeated daily crons will not expire a password
  test "repeated_crons_do_not_expire_old_passwords" do
    run_daily_cron_with_reset

    mock_user.update_column(:passwd_changed_on, pwd_date_if_now_expired - 1.days)

    @cron_repeats.times{ run_daily_cron }

    refute mock_user.must_change_passwd?,
      "Must change passwd should not be set to true - #{mock_user.inspect}"
  end


  # tests passwords are not expired before the expiration age
  test "password_should_not_expire_if_before_expiration_age" do
    mock_user.update_column(:passwd_changed_on, pwd_date_if_now_expired + 1.days)

    run_daily_cron_with_reset

    assert !mock_user.must_change_passwd?,
      "Should have must_change_passwd set to false #{mock_user.inspect}"
  end


  # tests no password expiration if setting is off
  test "password_should_not_expire_if_setting_is_off" do
    Setting.password_max_age = 0

    mock_user.update_column(:passwd_changed_on, pwd_date_if_now_expired - 1.days)

    run_daily_cron_with_reset

    assert !mock_user.must_change_passwd?,
      "Expiry off, must_change_passwd should be false #{mock_user.inspect}"
  end


  # when password expires, tests that an email is sent to the user
  # if the setting is on
  test "if_password_expired_send_mail_to_user_if_setting_on" do
    mock_user.update_column(:passwd_changed_on, pwd_date_if_now_expired - 1.days)

    run_daily_cron_with_reset

    assert all_mail_recipients.include?(@alice.mail),
      "User should be sent email on pwd expiry if setting on"
  end


  # tests that repeated daily crons do not send multiple emails
  test "repeated_crons_do_not_send_expiration_warn_mails_to_user" do
    run_daily_cron_with_reset

    mock_user.update_column(:passwd_changed_on, pwd_date_if_now_expired - 1.days)

    @cron_repeats.times{ run_daily_cron }

    @mail_subject = find_a_mail_subject_for_user(@alice)

    assert @mail_subject.blank?,
      "User should not be sent email on repeated crons - #{@mail_subject}"
  end


  # when password expires, tests that an email is not sent to the user
  # if the setting is off
  test "if_password_expired_dont_send_mail_to_user_if_setting_off" do
    Setting.password_max_age = 0

    mock_user.update_column(:passwd_changed_on, pwd_date_if_now_expired - 1.days)

    run_daily_cron_with_reset

    assert !all_mail_recipients.include?(@alice.mail),
      "User should not be sent email on pwd expiry if setting off"
  end

  # tests that an expiration email is sent when within the threshold
  test "expiration_warn_mails_when_setting_on_and_in_warn_range" do
    set_plugin_setting(:password_expiry_warn_days, 14)

    set_expiry_and_warn_vars

    @last_changed_date = Time.now.utc - (@expiry_days - @warn_threshold - 1).days

    while get_pwd_change_date(@test_user_login) > Time.now.utc - @expiry_days.days + 1.days do
      @last_changed_date = @last_changed_date - 1.days
      mock_user.update_column(:passwd_changed_on, @last_changed_date)

      if should_send_warning?(mock_user)
        send_successful_expiration_warn_mail_for(@expiry_days)
      else
        send_no_expiration_warn_mail_for(@expiry_days)
      end
    end
  end

  # tests no expiration mail sent when outside the warn range
  test "expiration_warn_mails_when_setting_on_and_out_of_warn_range" do
    set_plugin_setting(:password_expiry_warn_days, 14)

    set_expiry_and_warn_vars

    @last_changed_date = Time.now.utc - (@expiry_days - @warn_threshold - 1).days

    run_daily_cron_with_reset

    assert !all_mail_recipients.include?(@alice.mail),
      'No warn mails sent if out of warn range'
  end


  # tests that no expiration warning emails are sent when the setting is off
  test "no_expiration_warn_mails_when_setting_off" do
    set_plugin_setting(:password_expiry_warn_days, 0)

    @last_changed_date = pwd_date_if_now_expired + 1.days

    mock_user.update_column(:passwd_changed_on, @last_changed_date)

    run_daily_cron_with_reset

    assert !all_mail_recipients.include?(@alice.mail),
      "User should not be sent warn emails if setting off"
  end

  # tests that there is an expiration warning flash when setting is on and
  # the date is within the warn range
  test "expiration_warn_flash_when_setting_on_and_in_warn_range" do
    set_plugin_setting(:password_expiry_warn_days, 14)

    set_expiry_and_warn_vars

    @last_changed_date = Time.now.utc - (@expiry_days - @warn_threshold).days

    mock_user.update_column(:passwd_changed_on, @last_changed_date)

    attempt_login(@alice.password)

    assert !flash[:warning].blank?,
      "Warning should be flashed"
  end

  # tests that there is no expiration warning flash when setting is on and
  # the date is within the warn range
  test "no_expiration_warn_flash_when_setting_on_and_out_of_warn_range" do
    set_plugin_setting(:password_expiry_warn_days, 14)

    set_expiry_and_warn_vars

    @last_changed_date = Time.now.utc - (@expiry_days - @warn_threshold - 1).days

    mock_user.update_column(:passwd_changed_on, @last_changed_date)

    attempt_login(@alice.password)

    assert flash[:warning].blank?,
      "Warning should not be flashed"
  end

  # tests that there is no expiration warning flash when setting is off
  test "no_expiration_warn_flash_when_setting_off" do
    set_plugin_setting(:password_expiry_warn_days, 0)

    @last_changed_date = pwd_date_if_now_expired + 1.days

    mock_user.update_column(:passwd_changed_on, @last_changed_date)

    attempt_login(@alice.password)

    assert flash[:warning].blank?,
      "Warning should not be flashed if setting off"
  end

  def set_expiry_and_warn_vars
    @expiry_days = Setting.password_max_age.to_i
    @warn_threshold = Setting.plugin_redmine_account_policy[:password_expiry_warn_days].to_i
  end

  # successfully sends expiration warn mails and verifies they are correct
  def send_successful_expiration_warn_mail_for(expiry_days)
    ActionMailer::Base.deliveries = []

    run_daily_cron_with_reset

    @mail_subject = find_a_mail_subject_for_user(@alice)

    days_left = expiry_days - (Date.today - get_pwd_change_date(@alice.login).to_date).to_i

    assert @mail_subject.include?(days_left.to_s),
      "Subject should have #{days_left.to_s} days before expiration - #{@mail_subject}"
  end

  def send_no_expiration_warn_mail_for(expiry_days)
    ActionMailer::Base.deliveries = []

    run_daily_cron_with_reset

    @mail_subject = find_a_mail_subject_for_user(@alice)

    assert @mail_subject.blank?,
      "Subject should not exist : #{@mail_subject}"
  end

  def pwd_date_if_now_expired
    expiry_days = Setting.password_max_age.to_i
    Time.now.utc - expiry_days.days
  end

  def days_before_expiry(user)
    @password_max_age = Setting.password_max_age.to_i.days
    (last_change_pwd(user) + @password_max_age - Date.today).to_i
  end

  def last_change_pwd(user)
    (user.passwd_changed_on || user.created_on).to_date
  end

  def should_send_warning?(user)
    @warn_threshold = Setting.plugin_redmine_account_policy[:password_expiry_warn_days].to_i
    days_left = days_before_expiry(user)
    days_left == @warn_threshold || (@warn_threshold - days_left) % 7 == 0 || days_left == 1
  end

  def find_a_mail_subject_for_user(user)
    mail_subject = ''
    ActionMailer::Base.deliveries.each do |mail|
      if mail_recipients(mail).include?(user.mail)
        mail_subject = mail.subject.to_s
      end
    end
    mail_subject
  end
end
