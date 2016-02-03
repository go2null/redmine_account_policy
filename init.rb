# update 'must_change_passwd' on admin login

require_dependency 'redmine_account_policy/account_controller_patch'
require_dependency 'redmine_account_policy/controller_account_success_authentication_after_hook'
require_dependency 'redmine_account_policy/mailer_patch'
require_dependency 'redmine_account_policy/my_controller_patch'
require_dependency 'redmine_account_policy/user_patch'
require_dependency 'redmine_account_policy/hooks'
require_dependency 'redmine_account_policy/users_helper_patch'

Redmine::Plugin.register :redmine_account_policy do
	name 'Redmine Account Policy plugin'
	description 'Password Expiry and other enhancements'
	url 'https://github.com/go2null/redmine_account_policy'

	author 'go2null'
	author_url 'https://github.com/go2null'

	version '0.1.0'
	requires_redmine :version_or_higher => '2.6.0'

	settings :default => {
		# password complexity policy
		password_complexity: '3',

		# password expiry policy
		password_max_age: '90',

		# password reuse policy
		password_min_unique: '1', #TODO: Redmine checks new vs current
		password_min_age: '0',

		# invalid logins policy
		account_lockout_duration: '30',
		account_lockout_threshold: '6',
		notify_on_failure: 'off',
		notify_on_lockout: 'on',

		# unused accounts policy
		unused_account_max_age: '90',

		# daily cron hack
		account_policy_checked_on: ''
	}, :partial => 'settings/account_policy_settings'
end
#TODO: check out self.try_to_login
