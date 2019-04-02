class AddOldHashedPasswordsToUsers < ActiveRecord::Migration[5.0]
  def change
	# setting the size of the column to the size of a SHA512 hash (128)
	# multiplied by the maximum number of stored passwords (30) + 1
	add_column 	:users, 
	  :old_hashed_passwords, 
	  :string, 
	  :null => true,
	  :limit => (128 * 31)
  end
end
