#!/usr/bin/ruby

require 'json'
require 'yaml'
require 'net/http'
require 'uri'

class WebApi
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
  def debug
    @debug = true
  end
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
  def vehicles
    vehiclesUrl = URI.parse('https://portal.vn.teslamotors.com/vehicles')

    response = Net::HTTP.start(vehiclesUrl.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(vehiclesUrl.request_uri, { 'Cookie' => @cookies })
    end

    throw "Can't load vehicles" unless response.code == '200'

    return JSON.parse(response.body)
  end

  def doQuery(id, command)
    url = URI.parse("https://portal.vn.teslamotors.com/vehicles/#{id}/#{command}")

    response = Net::HTTP.start(url.host, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(url.request_uri, { 'Cookie' => @cookies })
    end

    p response if @debug
    p response.body if @debug
    throw "Can't get property #{response.code}" unless response.code == '200'

    return JSON.parse(response.body)
  end

  def doCommand(id, command)
    resp = doQuery(id, command)
    throw "Error executing command: #{resp['reason']}" unless resp['result']
    return resp
  end

  def mobileEnabled(id) doQuery(id, 'mobile_enabled') end
  def chargeState(id) doQuery(id, 'command/charge_state') end
  def climateState(id) doQuery(id, 'command/climate_state') end
  def driveState(id) doQuery(id, 'command/drive_state') end
  def vehicleState(id) doQuery(id, 'command/vehicle_state') end
  def guiSettings(id) doQuery(id, 'command/gui_settings') end

  def openChargePort(id) doCommand(id, 'command/charge_port_door_open') end
  def chargeStandard(id) doCommand(id, 'command/charge_standard') end
  def chargeMaxRange(id) doCommand(id, 'command/charge_max_range') end
  def chargeStart(id) doCommand(id, 'command/charge_start') end
  def chargeStop(id) doCommand(id, 'command/charge_stop') end
  def flashLights(id) doCommand(id, 'command/flash_lights') end
  def honkHorn(id) doCommand(id, 'command/honk_horn') end
  def doorUnlock(id) doCommand(id, 'command/door_unlock') end
  def doorLock(id) doCommand(id, 'command/door_lock') end
  def autoConditioningStart(id) doCommand(id, 'command/auto_conditioning_start') end
  def autoConditioningStop(id) doCommand(id, 'command/auto_conditioning_end') end
  def wakeUp(id) doCommand(id, 'command/wake_up') end

  def setTempsC(id, driver, passenger=driver)
    doCommand(id ,"command/set_temps?driver_temp=#{driver}&passengerTemp=#{passenger}")
  end

  def setTempsF(id, driver, passenger=driver)
    setTempsC(id, 5.0/9.0*(driver-32), 5.0/9.0*(passenger-32))
  end

  def sunRoofControl(id, state, percent=0) doCommand(id, "command/sun_roof_control?state=#{state}#{state=='move'?('&percent='+percent.to_s):''}") end

  def setChargeLimit(id, percent)
    doCommand(id, "command/set_charge_limit?percent=#{percent}")
  end

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
  p api.mobileEnabled(vehicles[0]["id"])
  p api.chargeState(vehicles[0]["id"])
  p api.climateState(vehicles[0]["id"])
  p api.driveState(vehicles[0]["id"])
  p api.vehicleState(vehicles[0]["id"])
end
