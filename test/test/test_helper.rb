# Load the Redmine helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')
Dir[File.expand_path('../../lib/redmine_account_policy', __FILE__) << '/*.rb'].each do |file|
  require file
end
