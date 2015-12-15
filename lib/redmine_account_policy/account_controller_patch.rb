module RedmineAccountPolicy
	module Patches
		module AccountControllerPatch
			$fails_log = Hash.new

			def self.included(base)
				base.send(:include, InstanceMethods)
				base.send(:include, ClassMethods)

			end


				# base.class_eval do
				# 	extend ClassMethods
				# 	class << self
				# 		alias_method_chain :invalid_credentials, :lockout_error
				#
				# end
 			#	alias_method_chain :invalid_credentials, :lockout_error

				# base.alias_method_chain



			module InstanceMethods
				#check password @user
				#TODO: Commented out include in controller_account_success_authentication_after_hook.rb
				# def password_authentication_with_user_from_login
				# 		user = User.try_to_login(params[:username], params[:password], false)
				# 		user_from_login = User.where("login = ?", params[:username]).take
				# 		puts "jasdfnsajf"
				# 		puts user_from_login.inspect
				# 		puts user_from_login.class
				#
				#
				# 		if user_from_login.nil?
				# 			invalid_credentials
				# 		elsif user.nil?
				# 			puts $fails_log.class
				# 			if $fails_log.has_key?(user_from_login.id)
				# 				puts "THEY IN THE HASH"
				# 				fails_log_value = $fails_log.fetch(user_from_login.id)
				# 				if fails_log_value.is_a? Integer
				# 				$fails_log[user_from_login.id] = fails_log_value + 1
				# 				puts "TIMES FAILED"
				# 				puts $fails_log[user_from_login.id]
				# 					if $fails_log.fetch(user_from_login.id) > 6
				# 						@settings[:fails_log][user_from_login.id] = DateTime.UtcNow + Setting.plugin_redmine_account_policy[:user_timeout_in_minutes].minutes
				# 					end
				# 				elsif fails_log_value.is_a? DateTime
				# 					unless DateTime.UtcNow < $fails_log.fetch(user_from_login.id).UtcNow
				# 						flash.now[:error] = l(:rpp_notice_account_locked)
				# 					end
				# 				end
				# 			end
				# 		else
				# 			$fails_log.delete(user_from_login.id)
				# 			puts "POPOFF THAT HASH"
				# 		end
				#
				# 	password_authentication_without_user_from_login
				# end


				def run_account_policy_daily_tasks
					expire_old_passwords!
					lock_unused_accounts!

					# TODO: doesn't persist to db; get's wipes out when save new password_lifetime
					Setting.plugin_redmine_account_policy.update({account_policy_checked_on: Date.today})
				end

				# enable must_change_passwd for all expired users.
				def expire_old_passwords!
					User.where(type: 'User', must_change_passwd: false).each do |user|
						user.update_attribute(:must_change_passwd, true) if user.password_expired?
					end
				end

				def lock_unused_accounts!
					User.where(type: 'User', status: [User::STATUS_REGISTERED, User::STATUS_ACTIVE]).each do |user|
						if user.account_unused?
							user.update_attribute(:must_change_passwd, true) if user.password_expired?
							user.lock!
						end
					end
				end
			end

			module ClassMethods

				def self.included(base)
					base.alias_method_chain :invalid_credentials, :lockout_error
				end

				def invalid_credentials_with_lockout_error
					user_from_login = User.where("login = ?", params[:username]).take
					if $fails_log.has_key?(user_from_login.id)
						fails_log_value = $fails_log.fetch(user_from_login.id)
						if fails_log_value.class.to_s.eql? "DateTime"
							if fails_log_value > DateTime.now.utc
								logger.warn "Failed login due to timeout lock for '#{params[:username]}' from #{request.remote_ip} at #{Time.now.utc}"
								flash.now[:error] = l(:rpp_notice_account_timeout) \
																		+ ((fails_log_value - DateTime.now.utc) * 1.days / 60).ceil.to_s \
																		+ " " + l(:rpp_setting_minute_plural) \
																		+ " or contact an administrator."
							end
						else
							invalid_credentials_without_lockout_error
							# logger.warn "Failed login due to timeout lock for '#{params[:username]}' from #{request.remote_ip} at #{Time.now.utc}"
							# flash.now[:error] = l(:rpp_notice_account_timeout) \
							# 										+ ((fails_log_value - DateTime.now.utc) * 1.days / 60).ceil.to_s \
							# 										+ " " + l(:rpp_setting_minute_plural) \
							# 										+ " or contact an administrator."
						end
					else
							invalid_credentials_without_lockout_error
					end
				end

			end
		end
	end
end

AccountController.send :include, RedmineAccountPolicy::Patches::AccountControllerPatch
