class Event
  attr_reader :client, :data
  def initialize(client, data = {})
    @client = client
    @data = data
  end

  # Fetch all events from the API
  def index
    client.get('tracker/events/')
  end

  # Create a new event with provided data
  def create(data)
    client.post('tracker/events/', data)
  end

  private

  # Parse the JSON response and return it
  def parse_response(response)
    JSON.parse(response)
  rescue JSON::ParserError
    { error: "Invalid JSON response" }
  end
end