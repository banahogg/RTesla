#!/usr/bin/ruby

require './webapi.rb'

StreamUrl = 'https://streaming.vn.teslamotors.com/stream/'

# Implements the real-time streaming API for the Model S
class Streamer
  # Takes username and password for the web API
  def initialize(username, password)
    @username = username
    @api = WebApi.new(username, password)

    getTokens
  end
  
  # Takes an optional array of values to request (default to all known values)
  # Yields a provided block a comma-separated string corresponding to the requested values
  # NOTE: Currently no way to end streaming
  def stream(values = ['speed', 'odometer', 'soc', 'elevation', 'est_heading', 'est_lat', 'est_lng', 'power', 'shift_state'])
    valuesString = values.join(',')

    streamUri = URI.parse "#{StreamUrl}#{@vid}/?values=#{valuesString}"

    http = Net::HTTP.new(streamUri.host, streamUri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 3*60

    streamReq = Net::HTTP::Get.new(streamUri.request_uri)
    streamReq.basic_auth(@username, @tokens[0])

    while true
      response = http.request(streamReq)
      if response.code != '200'
        getTokens
        streamReq.basic_auth(@username, @tokens[0])
        response = http.request(streamReq)
        throw "Can't restart streaming even with new tokens" unless response.code == '200'
      end
      yield response.body
    end
  end
  
  private
  
  # Get the token data from the non-streaming API to use the streaming API
  def getTokens
    v = @api.vehicles[0]

    @id = v["id"]
    @vid = v["vehicle_id"]

    @tokens = v['tokens']
  end
end

# Run the file to get a simple CSV dump from the streaming API
if $0 == __FILE__
  auth = YAML::load(File.new("auth.yaml"))
  stream = Streamer.new(auth['username'], auth['password'])
  count = 0
  values = ['speed', 'odometer', 'soc', 'elevation', 'est_heading', 'est_lat', 'est_lng', 'power', 'shift_state']
  puts "timestamp,"+values.join(',')
  stream.stream(values) do |x|
    puts x.chomp
    $stdout.flush
  end
end
