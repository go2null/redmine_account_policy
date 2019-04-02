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
          notify_user = Setting.plugin_redmine_account_policy['notify_on_lockout']
          set_instance_variables(user, ip_address)

          recipients = User.active.select { |u| u.admin? }.map(&:mail)

          recipients << user.mail if notify_user == 'on' 

          mail to: recipients, subject: l(:rap_mail_subject_login_lockout)
        end

        def notify_password_warn_expiry(user, days_left)
          @user = user

          mail to: user.mail, 
            subject: l(:rap_mail_subject_warn_expiry, days_left: days_left)
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
