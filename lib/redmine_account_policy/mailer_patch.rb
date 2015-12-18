module RedmineAccountPolicy
	module Patches
		module MailerPatch

			def self.included(base)
				base.send(:include, InstanceMethods)
			end

			module InstanceMethods
        def notify_login_failure(user, ip_address)
					set_instance_variables(user, ip_address)

					mail to: user.mail, subject: l(:rap_mail_subject_login_failure)
        end

        def notify_account_lockout(user, ip_address)
					set_instance_variables(user, ip_address)

        	admins = User.active.select { |u| u.admin? }.map(&:mail)
					mail to: user.mail, bcc: admins, subject: l(:rap_mail_subject_login_lockout)
        end

        def set_instance_variables(user, ip_address)
        	# set instance variables to use in mailer views
        	@user = user
        	@ip_address = ip_address
        end

			end
		end
	end
end

Mailer.send :include, RedmineAccountPolicy::Patches::MailerPatch
