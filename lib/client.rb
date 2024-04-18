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
    @cookie_string = response['Set-Cookie'] if response['Set-Cookie']
  end

  def ok
    current_uri = full_path('dhis-web-dashboard/')
    request = Net::HTTP::Get.new(current_uri)
    response = send_request(request)
    handle_http_errors(response)
  end

  def handle_http_errors(response, redirect_count = 0)
    case response.code.to_i
    when 200..201
      response
    when 400
      puts 'Error: Bad Request'
      puts "Response Body: #{response.body}"
      exit # This will terminate the script. Remove if you want the script to continue regardless of errors.
    when 401
      puts 'Error: Unauthorized'
      exit
    when 403
      puts 'Error: Forbidden'
      exit
    when 404
      puts 'Error: Not Found'
      exit
    when 409
      puts 'Error: Conflict'
      exit
    when 500..599
      puts 'Error: Server Error'
      puts "Response Body: #{response.body}"
      exit
    when 301..302 # handle both permanent and temporary redirects
      handle_http_redirects(response, redirect_count)
    end
  end

  def handle_http_redirects(response, redirect_count)
    if redirect_count >= MAX_REDIRECTS
      puts "Exceeded maximum redirect limit of #{MAX_REDIRECTS}"
    else
      current_uri = URI(response['location']) # Update the URI from the "Location" header
      puts "Redirected to #{current_uri}"
      request = Net::HTTP::Get.new(current_uri)
      response = send_request(request)
      handle_http_errors(response, redirect_count + 1)
    end
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
