require 'active_record'
require 'pg' # PostgreSQL adapter
require 'logger'
require 'dotenv'

Dotenv.load('.env')

# Setup Logger
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Database Configuration
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DHIS2_DB_HOST'],
  port: ENV['DHIS2_DB_PORT'],
  username: ENV['DHIS2_DB_USERNAME'],
  password: ENV['DHIS2_DB_PASSWORD'],
  database: ENV['DHIS2_DB_NAME']
)

# Test the connection
begin
  ActiveRecord::Base.connection
  puts 'Connection successful!'
rescue ActiveRecord::NoDatabaseError => e
  puts "Failed to connect: #{e.message}"
end
