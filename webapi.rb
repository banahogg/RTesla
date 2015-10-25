#!/usr/bin/ruby

require 'json'
require 'yaml'
require 'net/http'
require 'uri'

class Vehicle
  # Create a Vehicle with given API object and id
  def initialize(token, prop, debug)
    @token = token
    @prop = prop
    @id = prop['id']
    @debug = debug
  end
  
  attr_reader :prop

  # Low-level function to run a query
  def doQuery(command)
    url = URI.parse("https://owner-api.teslamotors.com/api/1/vehicles/#{@id}/#{command}")

    response = Net::HTTP.start(url.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(url.request_uri, { 'Authorization' => "Bearer #{@token}" })
    end

    p response if @debug
    p response.body if @debug
    throw "Can't get property #{response.code}" unless response.code == '200'

    return JSON.parse(response.body)["response"]
  end

  # Function to run a command
  # Adds handling for command return values on top of the query handling
  def doCommand(command)
    url = URI.parse("https://owner-api.teslamotors.com/api/1/vehicles/#{@id}/#{command}")

    response = Net::HTTP.start(url.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.post(url.request_uri, "", { 'Authorization' => "Bearer #{@token}" })
    end

    p response if @debug
    p response.body if @debug
    throw "Can't get property #{response.code}" unless response.code == '200'

    resp = JSON.parse(response.body)["response"]

    throw "Error executing command: #{resp['reason']}" unless resp['result']

    return resp
  end

  def awake() @prop['state'] == "online" end
  def mobileEnabled() doQuery('mobile_enabled') end
  def chargeState() doQuery('data_request/charge_state') end
  def climateState() doQuery('data_request/climate_state') end
  def driveState() doQuery('data_request/drive_state') end
  def vehicleState() doQuery('data_request/vehicle_state') end
  def guiSettings() doQuery('data_request/gui_settings') end

  def openChargePort() doCommand('command/charge_port_door_open') end
  def chargeStandard() doCommand('command/charge_standard') end
  def chargeMaxRange() doCommand('command/charge_max_range') end
  def chargeStart() doCommand('command/charge_start') end
  def chargeStop() doCommand('command/charge_stop') end
  def flashLights() doCommand('command/flash_lights') end
  def honkHorn() doCommand('command/honk_horn') end
  def doorUnlock() doCommand('command/door_unlock') end
  def doorLock() doCommand('command/door_lock') end
  def autoConditioningStart() doCommand('command/auto_conditioning_start') end
  def autoConditioningStop() doCommand('command/auto_conditioning_end') end
  def wakeUp() doCommand('wake_up') end

  def setTempsC(driver, passenger=driver)
    doCommand("command/set_temps?driver_temp=#{driver}&passengerTemp=#{passenger}")
  end

  def setTempsF(driver, passenger=driver)
    setTempsC(5.0/9.0*(driver-32), 5.0/9.0*(passenger-32))
  end

  def sunRoofControl(state, percent=0) doCommand("command/sun_roof_control?state=#{state}#{state=='move'?('&percent='+percent.to_s):''}") end

  def setChargeLimit(percent)
    doCommand("command/set_charge_limit?percent=#{percent}")
  end

  def remoteStartDrive(password)
    doCommand("command/remote_start_drive?password=#{password}")
  end
end

# Basic read/write Model S web API
class WebApi

  TeslaClientId = 'e4a9949fcfa04068f59abb5a658f2bac0a3428e4652315490b659d5ab3f35a9e'
  TeslaClientSecret = 'c75f14bbadc8bee3a7594412c31416f8300256d7668ea7e6e7f06727bfb9d220'

  def login(username, password)
    loginUrl = URI.parse('https://owner-api.teslamotors.com/oauth/token')

    response = Net::HTTP.start(loginUrl.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      request = Net::HTTP::Post.new(loginUrl.request_uri)
      request.set_form_data({"grant_type" => 'password',
                             "client_id" => TeslaClientId,
                             "client_secret" => TeslaClientSecret,
                             "email" => username,
                             "password" => password})
      http.request(request)
    end

    throw "Login failed" unless response.code == '200'

    @token = JSON.parse(response.body)['access_token']
  end
  
  # Set debugging code on or off
  def debug(debug = true)
    @debug = debug
  end
  
  # Allocates a new WebApi object with the username and password provided
  # Gives preference to existing cached cookies
  def initialize(username, password)
    @debug = false
    begin
      @token = YAML::load(File.new("token.txt"))
      self.vehicles
    rescue
      self.login(username, password)
      self.saveToken
    end
  end
  
  # Returns an array of vehicles, each of which is a hash
  # The id for for the commands below is in the "id" key of the vehicle
  def vehicles
    vehiclesUrl = URI.parse('https://owner-api.teslamotors.com/api/1/vehicles')

    response = Net::HTTP.start(vehiclesUrl.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(vehiclesUrl.request_uri, { 'Authorization' => "Bearer #{@token}" })
    end

    throw "Can't load vehicles" unless response.code == '200'

    vehicles = JSON.parse(response.body)

    return vehicles['response'].map {|x| Vehicle.new(@token, x, @debug)}
  end

  # Save the current login tokens to a file "token.txt"
  def saveToken
    File.open("token.txt", "w") do |f|
      f.write(@token.to_yaml)
    end
  end
end

if $0 == __FILE__
  auth = YAML::load(File.new("../teslaremote/auth.yaml"))

  api = WebApi.new(auth['username'], auth['password'])

  vehicles = api.vehicles
  p vehicles[0]
  p vehicles[0].mobileEnabled
  p vehicles[0].awake
  if vehicles[0].awake
    p vehicles[0].mobileEnabled
    p vehicles[0].chargeState
    p vehicles[0].climateState
    p vehicles[0].driveState
    p vehicles[0].vehicleState
  end
end
