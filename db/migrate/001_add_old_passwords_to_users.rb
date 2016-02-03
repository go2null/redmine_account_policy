class AddOldPasswordsToUsers < ActiveRecord::Migration
	def up
		add_column :users, :old_passwords, :string, null: true
	end
end
