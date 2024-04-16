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
    @http.use_ssl = (@base_uri.scheme == 'https')
    @cookie_string = ''
  end

  def send_request(request)
    # Add stored cookies to the request
    request['Cookie'] = @cookie_string unless @cookie_string.empty?
    request['Authorization'] = auth_header

    response = http.request(request)
    # Update the cookie string with new cookies from the response
    update_cookie_string(response)
    response
  end

  def update_cookie_string(response)
    if response['Set-Cookie']
      @cookie_string = response['Set-Cookie']
    end
  end

  def ok
    current_uri = full_path('dhis-web-dashboard/')
    redirect_count = 0

    loop do
      request = Net::HTTP::Get.new(current_uri)
      response = send_request(request)

      case response.code
      when '200'
        return response
      when '302', '301' # handle both permanent and temporary redirects
        if redirect_count >= MAX_REDIRECTS
          puts "Exceeded maximum redirect limit of #{MAX_REDIRECTS}"
          return response
        else
          redirect_count += 1
          current_uri = URI(response['location']) # Update the URI from the "Location" header
          puts "Redirected to #{current_uri}"
          next # Continue the loop with the new URI
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

  def get(path, query_params = {})
    request = Net::HTTP::Get.new(full_path(path, query_params))

    response = send_request(request)
    handle_http_errors(response)
    parse_response(response.body)
  end

  def post(path, payload, query_params = {})
    request = Net::HTTP::Post.new(full_path(path, query_params))
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = send_request(request)
    handle_http_errors(response)
    parse_response(response.body)
  end

  def delete(path, query_params = {})
    request = Net::HTTP::Delete.new(full_path(path, query_params))

    response = send_request(request)
    handle_http_errors(response)
    parse_response(response.body)
  end

  private

  def full_path(path, query_params = {})
    uri = URI.join(@base_uri.to_s, path)
    uri.query = URI.encode_www_form(query_params) unless query_params.empty?
    uri.to_s
  end

  # Parse the JSON response and return it
  def parse_response(response)
    JSON.parse(response)
  rescue JSON::ParserError
    { error: 'Invalid JSON response' }
  end
end
