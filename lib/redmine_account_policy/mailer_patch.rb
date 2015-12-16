module RedmineAccountPolicy
	module Patches
		module MailerPatch

			def self.included(base)
				base.send(:include, InstanceMethods)
			end

			module InstanceMethods

        def on_each_fail_notification(user_to_notify)
					mail to: user_to_notify.mail, subject: (l(:rpp_subject_failed_login) + DateTime.now.to_formatted_s(:long_ordinal))
        end

        def on_max_fails_notification(user_to_notify)
					@user = user_to_notify
					recipients = User.active.where(:admin => true)
					if Setting.plugin_redmine_account_policy[:email_notify_on_max_fails].eql? 'on'
						recipients = User.active.where('(admin = true) OR (id = ?)', @user.id )
					else
						recipients = User.active.where(:admin => true)
					end
					mail to: recipients, subject: (l(:rpp_subject_max_login_failures) + DateTime.now.to_formatted_s(:long_ordinal))
        end


			end

		end
	end
end

Mailer.send :include, RedmineAccountPolicy::Patches::MailerPatch
