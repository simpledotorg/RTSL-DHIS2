# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'base64'

class Client
  MAX_REDIRECTS = 10
  attr_reader :base_uri, :username, :password, :auth_header, :http

  def initialize(base_uri, username, password)
    @base_uri = URI(base_uri)
    @username = username
    @password = password
    @auth_header = "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
    # Set up an HTTP object for the base URL
    @http = Net::HTTP.new(@base_uri.host, @base_uri.port)
    # Use SSL/TLS if the URI scheme is HTTPS
    @http.use_ssl = (@base_uri.scheme == "https")
  end

  def ok
    current_uri = full_path('dhis-web-dashboard/')
    redirect_count = 0

    loop do
      request = Net::HTTP::Get.new(current_uri)
      request['Authorization'] = @auth_header
      response = @http.request(request)

      case response.code
      when "200"
        return response
      when "302", "301"  # handle both permanent and temporary redirects
        if redirect_count >= MAX_REDIRECTS
          puts "Exceeded maximum redirect limit of #{MAX_REDIRECTS}"
          return response
        else
          redirect_count += 1
          current_uri = URI(response['location'])  # Update the URI from the "Location" header
          puts "Redirected to #{current_uri}"
          next  # Continue the loop with the new URI
        end
      else
        puts "HTTP Request failed: #{response.code}"
        return response
      end
    end
  end


  def handle_http_errors(response)
    # todo
  end

  def handle_http_redirects(current_uri, response)
    # todo
  end

  def get(path, params = {})
    request = Net::HTTP::Get.new(full_path(path, params))
    request['Authorization'] = @auth_header

    response = @http.request(request)
    handle_http_errors(response)
    response.body
  end

  def post(path, data, params = {})
    request = Net::HTTP::Post.new(full_path(path, params))
    request['Authorization'] = @auth_header
    request['Content-Type'] = 'application/json'
    request.body = data.to_json

    response = @http.request(request)
    handle_http_errors(response)
    response.body
  end

  private

  def full_path(path, params = {})
    uri = URI.join(@base_uri.to_s, path).to_s
    uri.query = URI.encode_www_form(params) unless params.empty?
    uri
  end

end


# client = Client.new("http://localhost:8080/","admin" , "district")
# response = client.get("api/tracker/events/")
# puts response.body
#
# program_id = 'program_id' # Specify the program ID for which you want to create events
# event_data = {
#   program: 'pMIglSEqPGS',
#   eventDate: '2024-04-10',
#   orgUnit: 'SDXi1tscdL7', # Specify the organization unit ID
#   dataValues: [
#     { dataElement: 'data_element_id', value: 'value' },
#   # Add more data elements and values as needed
#   ]
# }


# event = Event.new(client)
#
# # List all events
# events = event.index
# puts "Events: #{events}"
#
# # Create a new event
# new_event_data = { title: "New Conference", date: "2024-05-01" }
# new_event = event.create(new_event_data)
# puts "Created Event: #{new_event}"
# headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }

