#!/usr/bin/ruby

require 'json'
require 'yaml'
require 'net/http'
require 'uri'

class Vehicle
  # Create a Vehicle with given API object and id
  def initialize(cookies, prop)
    @cookies = cookies
    @prop = prop
    @id = prop['id']
  end
  
  # Low-level function to run a query
  def doQuery(command)
    url = URI.parse("https://portal.vn.teslamotors.com/vehicles/#{@id}/#{command}")

    response = Net::HTTP.start(url.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(url.request_uri, { 'Cookie' => @cookies })
    end

    p response if @debug
    p response.body if @debug
    throw "Can't get property #{response.code}" unless response.code == '200'

    return JSON.parse(response.body)
  end

  # Function to run a command
  # Adds handling for command return values on top of the query handling
  def doCommand(command)
    resp = doQuery(command)
      throw "Error executing command: #{resp['reason']}" unless resp['result']
    return resp
  end

  def awake() @prop['state'] != "asleep" end
  def mobileEnabled() doQuery('mobile_enabled') end
  def chargeState() doQuery('command/charge_state') end
  def climateState() doQuery('command/climate_state') end
  def driveState() doQuery('command/drive_state') end
  def vehicleState() doQuery('command/vehicle_state') end
  def guiSettings() doQuery('command/gui_settings') end

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
  def wakeUp() doCommand('command/wake_up') end

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
end

# Basic read/write Model S web API
class WebApi

  # Takes username and password and generates login cookies
  def login(username, password)
    loginUrl = URI.parse('https://portal.vn.teslamotors.com/login')

    response = Net::HTTP.start(loginUrl.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      request = Net::HTTP::Post.new(loginUrl.request_uri)
      request.set_form_data({"user_session[email]" => username,
                             "user_session[password]" => password})

      http.request(request)
    end

    throw "Login failed" unless response.code == '302'

    all_cookies = response.get_fields('set-cookie')
    cookies_array = Array.new
    all_cookies.each { | cookie |
      cookies_array.push(cookie.split('; ')[0])
    }
    @cookies = cookies_array.join('; ')
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
      @cookies = YAML::load(File.new("cookies.txt"))
      self.vehicles
    rescue
      self.login(username, password)
      self.saveCookies
    end
  end
  
  # Returns an array of vehicles, each of which is a hash
  # The id for for the commands below is in the "id" key of the vehicle
  def vehicles
    vehiclesUrl = URI.parse('https://portal.vn.teslamotors.com/vehicles')

    response = Net::HTTP.start(vehiclesUrl.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(vehiclesUrl.request_uri, { 'Cookie' => @cookies })
    end

    throw "Can't load vehicles" unless response.code == '200'

    vehicles = JSON.parse(response.body)
    
    return vehicles.map {|x| Vehicle.new(@cookies, x)}
  end

  # Save the current login cookies to a file "cookies.txt"
  def saveCookies
    File.open("cookies.txt", "w") do |f|
      f.write(@cookies.to_yaml)
    end
  end
end

if $0 == __FILE__
  auth = YAML::load(File.new("auth.yaml"))

  api = WebApi.new(auth['username'], auth['password'])

  vehicles = api.vehicles
  p vehicles
  p vehicles[0].mobileEnabled
  p vehicles[0].chargeState
  p vehicles[0].climateState
  p vehicles[0].driveState
  p vehicles[0].vehicleState
end
