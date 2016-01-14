module RedmineUserAccounts
	class Hooks < Redmine::Hook::ViewListener

		# This just renders the partial in
		# app/views/hooks/my_plugin/_view_issues_form_details_bottom.rhtml
		# The contents of the context hash is made available as local variables to the partial.
		#
		# Additional context fields
		#   :issue  => the issue this is edited
		#   :f      => the form object to create additional fields
		render_on :view_my_account_contextual,
			:partial => 'hooks/redmine_account_policy/view_my_account_contextual'

		end
end
