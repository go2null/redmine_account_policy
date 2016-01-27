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
        
	def notify_password_warn_expiry(user)
					@user = user
					password_max_age = (Setting.password_max_age.to_i.days==0) ? Setting.plugin_redmine_account_policy[:password_max_age].to_i.days : Setting.password_max_age.to_i.days

					mail to: user.mail, subject: l(:rap_mail_subject_warn_expiry, days_left: ((((@user.passwd_changed_on || @user.created_on).to_date + password_max_age) - Date.today).to_i))
        end
	
	def notify_password_is_expired(user)
					@user = user
					mail to: user.mail, subject: l(:rap_mail_subject_warn_expiry)
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
