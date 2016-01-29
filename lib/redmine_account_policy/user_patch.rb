module RedmineAccountPolicy
	module Patches
		module UserPatch

			def self.included(base)
				base.send(:include, InstanceMethods)
				# == password complexity == #
				base.alias_method_chain :validate_password_length, :account_policy
				# == password reuse == #
				base.alias_method_chain :change_password_allowed?, :account_policy
				base.alias_method_chain :salt_password, :account_policy
			end

			module InstanceMethods
				# == password complexity AND password reuse== #

				def validate_password_length_with_account_policy
					validate_password_length_without_account_policy

					errors.add(:base, l(:rap_error_password_complexity)) unless complex_enough?(password)

					#TODO: min_unique = Setting.plugin_redmine_account_policy[:password_max_age].to_i
					#errors.add(:base, l(:rap_error_password_reuse, min_unique)) unless unique_enough?(password)
				end


				# == password expiry == #

				# TODO: should be in, for example, an ApplicationPatch module
				def password_max_age
					Setting.plugin_redmine_account_policy[:password_max_age].to_i
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def password_expiry_policy_enabled?
					password_max_age > 0
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


				# == password reuse == #

				def salt_password_with_account_policy(clear_password)
					#current Redmine implementation only tracks current password (does current password 
					#match new password?), so a new salt is generated every time the password is changed.
					#If we want to track multiple passwords, the user's salt must not change, so if the setting is enabled, 
					#skip salt generation
					if Setting.plugin_redmine_account_policy[:password_min_unique].to_i > 1 
						self.hashed_password = User.hash_password("#{salt}#{User.hash_password clear_password}")
						self.passwd_changed_on = Time.now.change(:usec => 0)
					else
						salt_password_without_account_policy(clear_password)
					end 
					
				end

				def change_password_allowed_with_account_policy?
					min_age = Setting.plugin_redmine_account_policy[:password_min_age].to_i
					unless passwd_changed_on.blank?
						return false if passwd_changed_on > (Time.zone.now - min_age.days)
					end
					change_password_allowed_without_account_policy?
				end


				# == lock unused accounts == #

				# TODO: should be in, for example, an ApplicationPatch module
				def unused_account_max_age
					Setting.plugin_redmine_account_policy[:unused_account_max_age].to_i
				end

				# TODO: should be in, for example, an ApplicationPatch module
				def unused_account_policy_enabled?
					unused_account_max_age > 0
				end

				def account_unused?
					return false unless unused_account_policy_enabled?

					(last_login_on || created_on).to_date + unused_account_max_age <= Date.today
				end

				private

				def complex_enough?(password)
					complexity = Setting.plugin_redmine_account_policy[:password_complexity].to_i
					return true if complexity == 0

					count = 0
					count += 1 if password =~ /[A-Z]/
					count += 1 if password =~ /[a-z]/
					count += 1 if password =~ /[0-9]/
					count += 1 if password =~ /[^A-Za-z0-9]/

					count >= complexity
				end

				def unique_enough?(password)
					# TODO
				end

			end
		end
	end
end

User.send(:include, RedmineAccountPolicy::Patches::UserPatch)
