require 'active_record'
require 'pg' # PostgreSQL adapter
require 'logger'

# Setup Logger
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Database Configuration
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: 'localhost',
  port: '7432',
  username: 'dhis',
  password: 'dhis',
  database: 'dhis'
)

# Test the connection
begin
  ActiveRecord::Base.connection
  puts "Connection successful!"
rescue ActiveRecord::NoDatabaseError => e
  puts "Failed to connect: #{e.message}"
end
