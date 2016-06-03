require File.expand_path('../../test_helper', __FILE__)


class MailerTest < ActionMailer::TestCase
  include TestSetupMethods

  def setup
    @mock_user_login = 'alice'
    @mock_user_login = '1234567890'
    @mock_user_mail = 'alice@doe.com'
    @mock_user_ip = '127.0.0.1'

    create_mock_user
  end

  # tests if email sent on function call
  test "notify_login_failure" do
    mail = Mailer.notify_login_failure(User.find_by_login(@mock_user_login), 
                                       @mock_user_ip).deliver

    if Setting.bcc_recipients == '1'
      assert mail.bcc.include?(@mock_user_mail),
        'LOGIN FAIL bcc recipient should be equal to user_mail' + mail.inspect
    else
      assert mail.to.include?(@mock_user_mail),
        'LOGIN FAIL recipient should be equal to user_mail' + mail.inspect
    end

    assert !ActionMailer::Base.deliveries.empty?
  end

  # tests if email sent on function call and sent to admins
  test "notify_account_lockout" do
    Setting.plugin_redmine_account_policy.update({notify_on_lockout: 'on'})
    mail = Mailer.notify_account_lockout(User.find_by_login(@mock_user_login), 
                                         @mock_user_ip).deliver
    admins = User.active.select { |u| u.admin? }.map(&:mail) 
    if Setting.bcc_recipients == '1'
      assert mail.bcc.include?(@mock_user_mail),
        'LOCKOUT bcc recipient should be equal to user_mail' + mail.inspect
      assert (admins - mail.bcc).empty?,
        'LOCKOUT Admins should be in bcc'
    else
      assert mail.to.include?(@mock_user_mail),
        'LOCKOUT recipient should be equal to user_mail' + mail.inspect
      assert (admins - mail.to).empty?,
        'LOCKOUT Admins should be in recipients'
    end

    assert !ActionMailer::Base.deliveries.empty?
  end

  # tests if email sent on function call
  test "notify_password_warn_expiry" do
    # passing in arbitrary integer for days_left parameter
    mail = Mailer.notify_password_warn_expiry(User.find_by_login(@mock_user_login), 1).deliver

    if Setting.bcc_recipients == '1'
      assert mail.bcc.include?(@mock_user_mail),
        'WARN EXPIRY bcc recipient should be equal to user_mail' + mail.inspect
    else
      assert mail.to.include?(@mock_user_mail),
        'WARN EXPIRY recipient should be equal to user_mail' + mail.inspect

    end

    assert !ActionMailer::Base.deliveries.empty?
  end

  # tests if email sent on function call
  test "notify_password_is_expired" do
    mail = Mailer.notify_password_is_expired(User.find_by_login(@mock_user_login)).deliver

    if Setting.bcc_recipients == '1'
      assert mail.bcc.include?(@mock_user_mail),
        'IS EXPIRED bcc recipient should be equal to user_mail' + mail.inspect
    else
      assert mail.to.include?(@mock_user_mail),
        'IS EXPIRED recipient should be equal to user_mail' + mail.inspect

    end

    assert !ActionMailer::Base.deliveries.empty?
  end

end
