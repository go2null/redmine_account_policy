# update 'must_change_passwd' on admin login
require_dependency 'redmine_account_policy/user_patch'
require_dependency 'redmine_account_policy/account_controller_patch'
require_dependency 'redmine_account_policy/controller_account_success_authentication_after_hook'

# display 'password expired' notice
require_dependency 'redmine_account_policy/my_controller_patch'

Redmine::Plugin.register :redmine_account_policy do
	name 'Redmine Account Policy plugin'
	description 'Password Expiry and other enhancements'
	url 'https://github.com/go2null/redmine_account_policy'

	author 'go2null'
	author_url 'https://github.com/go2null'

	version '0.0.2'
	requires_redmine :version_or_higher => '2.6.0'

	settings :default => {
		password_max_age: '90',
		unused_account_max_age: '90',
		account_policy_checked_on: '',
		email_notify_on_each_fail: false,
		email_notify_on_max_fails: true,
		max_login_fails: 6,
		user_timeout_in_minutes: 5,
		fails_log: Hash.new
	}, :partial => 'settings/account_policy_settings'
end
#TODO: check out self.try_to_login
