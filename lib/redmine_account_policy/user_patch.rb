module RedmineAccountPolicy
	module Patches
		module UserPatch

			def self.included(base)
				base.send(:include, InstanceMethods)
				base.alias_method_chain :check_password?, :count_fails
				base.alias_method_chain :validate_password_length, :account_policy_extra_settings

			end

			module InstanceMethods
			
#			  def validate_password_length
 #   return if password.blank? && generate_password?
  #  # Password length validation based on setting
   # if !password.nil? && password.size < Setting.password_min_length.to_i
     # errors.add(:password, :too_short, :count => Setting.password_min_length.to_i)
    #end
 # end
			
				def validate_password_length_with_account_policy_extra_settings
					check_lower_case = Setting.plugin_redmine_account_policy[:lower_case_in_pass].eql? 'on'
					check_upper_case = Setting.plugin_redmine_account_policy[:upper_case_in_pass].eql? 'on'
					check_numeric = Setting.plugin_redmine_account_policy[:numerical_in_pass].eql? 'on'
					check_nonalphanumeric = Setting.plugin_redmine_account_policy[:nonalphanumeric_in_pass].eql? 'on'
					
					puts check_lower_case
					puts check_upper_case
					puts check_numeric
					puts check_nonalphanumeric
					
					if check_lower_case
						errors.add(:base,'Password must contain a lower case character [a-z]') unless (password =~ /([[:lower:]]+)/)
					end
					
					if check_upper_case
						errors.add(:base,'Password must contain an upper case character [A-Z]') unless (password =~ /([[:upper:]]+)/)
					end
					
					if check_numeric
						errors.add(:base,'Password must contain a numeric character [0-9]') unless (password =~ /([0-9]+)/)
					end
					
					if check_nonalphanumeric
						errors.add(:base,'Password must contain a non-alphanumeric character (such as !$#,)') unless (password =~ /([^[:alnum:]]+)/)
					end
				
				
		
				
				
					validate_password_length_without_account_policy_extra_settings
				end

				def check_password_with_count_fails?(clear_password)

					if $fails_log.has_key?(id)
					 fails_log_value = $fails_log.fetch(id)
					 if fails_log_value.class.to_s.eql? "DateTime"
						 if fails_log_value > DateTime.now.utc
						 	false
						 else
							 $fails_log.delete(id)
							 check_password_without_count_fails
						end
					 elsif check_password_without_count_fails?(clear_password)
						 $fails_log.delete(id)
						 true
					 else
						if fails_log_value.is_a? Fixnum
							$fails_log[id] = fails_log_value + 1
							if $fails_log.fetch(id).to_s >= Setting.plugin_redmine_account_policy[:max_login_fails]
								Mailer.on_max_fails_notification(self).deliver
						 		$fails_log[id] = DateTime.now.utc + Setting.plugin_redmine_account_policy[:user_timeout_in_minutes].to_i.minutes
						 	end
						 	false
						end
					 end

				 else
					 return true if check_password_without_count_fails?(clear_password)
					 $fails_log[id] = 1
					 false
				 end
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def password_max_age
					Setting.plugin_redmine_account_policy[:password_max_age].to_i
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def password_expiry_policy_enabled?
					password_max_age > 0
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def unused_account_max_age
					Setting.plugin_redmine_account_policy[:unused_account_max_age].to_i
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def unused_account_policy_enabled?
					unused_account_max_age > 0
				end


				# Can only be expired if lifetime is set and is not 0.
				def password_expired?
					# only expired if password_max_age set, and > 0
					return false unless password_expiry_policy_enabled?

					(passwd_changed_on || created_on).to_date + password_max_age <= Date.today
				end

				# TODO: prefered to override 'must_change_password?' and use super
				# but it doesn't work
				#def must_change_password_with_policy?
				#	if password_expired?
				#self.must_change_passwd = true
				#error.add 'expired!'
				#	end

				#	must_change_password_without_policy?
				#end

				def account_unused?
					return false unless unused_account_policy_enabled?

					(last_login_on || created_on).to_date + unused_account_max_age <= Date.today
				end
			end

		end
	end
end

User.send(:include, RedmineAccountPolicy::Patches::UserPatch)
