-- DriveTech: BMW-style driving electronics for BeamNG.drive vehicles.
--
-- Loaded automatically for every vehicle (lua/vehicle/extensions/auto).
-- Every feature checks whether the vehicle supports it and stays inactive
-- otherwise. Nothing is touched while no player sits in the vehicle, and every
-- feature restores the original state when it is switched off or fails.

local M = {}

local config = require("driveTech/config")
local featureNames = {"stability", "xdrive", "shiftLogic", "pedalMap", "launch", "startStop", "autoHold", "coasting"}

local ctx = nil
local PROFILE_INDEX = {eco = 0, comfort = 1, sport = 2, sportPlus = 3}
local STABILITY_INDEX = {dsc = 0, dtc = 1, off = 2}
local features = {}
local hasRegisteredMenu = false
local wasPlayerSeated = false

local function message(text, duration, id)
  if ctx and ctx.settings.showMessages then
    guihooks.message("DriveTech: " .. text, duration or 3, "vehicle.driveTech." .. (id or "info"))
  end
end

local function getModelKey()
  local cfg = v and v.config
  local key = cfg and (cfg.model or cfg.mainPartName)
  if not key and v and v.data and v.data.information then
    key = v.data.information.model
  end
  return key or "unknown"
end

local function findDevice(typeName)
  for _, device in pairs(powertrain.getDevices() or {}) do
    if device.type == typeName then
      return device
    end
  end
end

local function buildContext()
  local engine = powertrain.getDevice("mainEngine") or findDevice("combustionEngine")
  local gearbox = powertrain.getDevice("gearbox")
  local converter = findDevice("torqueConverter")

  ctx = {
    modelKey = getModelKey(),
    engine = (engine and engine.setTempRevLimiter) and engine or nil,
    gearbox = gearbox,
    gearboxType = gearbox and gearbox.type or "none",
    -- converter features are skipped when another system already drives the impeller clutch
    converter = (converter and not controller.getController("rimPullControl")) and converter or nil,
    message = message,
    converterRequests = {},
    lastConverterCoef = 1
  }
  ctx.isDiesel = ctx.engine and ctx.engine.requiredEnergyType == "diesel" or false
  ctx.isAutomatic = ctx.gearboxType == "automaticGearbox" or ctx.gearboxType == "dctGearbox" or ctx.gearboxType == "cvtGearbox"
  ctx.settings = config.load(ctx.modelKey)
  ctx.profile = ctx.settings.profiles.default
  ctx.stability = ctx.settings.stability.default
end

local function runFeature(name, fnName, ...)
  local feature = features[name]
  if not feature or feature.failed or not feature[fnName] then
    return
  end
  local ok, err = pcall(feature[fnName], ctx, ...)
  if not ok then
    feature.failed = true
    log("E", "driveTech", string.format("Feature '%s' failed in %s and was disabled: %s", name, fnName, tostring(err)))
    if feature.restore then
      pcall(feature.restore, ctx)
    end
  end
end

local function forEachFeature(fnName, ...)
  for _, name in ipairs(featureNames) do
    runFeature(name, fnName, ...)
  end
end

local function applyConverter()
  if not ctx.converter then
    return
  end
  local coef = 1
  for _, requested in pairs(ctx.converterRequests) do
    coef = math.min(coef, requested)
  end
  if coef < 1 or ctx.lastConverterCoef < 1 then
    ctx.converter.impellerClutchCoef = coef
    ctx.lastConverterCoef = coef
  end
end

local function cycle(list, current)
  for i, key in ipairs(list) do
    if key == current then
      return list[i % #list + 1]
    end
  end
  return list[1]
end

-- Public API (used by the radial menu and key bindings) ----------------------

function M.setProfile(profile, silent)
  if not ctx or not ctx.settings.profiles.enabled then
    return
  end
  ctx.profile = profile
  forEachFeature("onProfileChanged")
  if not silent then
    message("Profile " .. (ctx.settings.profiles.names[profile] or profile), 3, "profile")
  end
end

function M.cycleProfile()
  if ctx then
    M.setProfile(cycle(ctx.settings.profiles.order, ctx.profile))
  end
end

function M.setStability(mode, silent)
  if not ctx or not ctx.settings.stability.enabled then
    return
  end
  ctx.stability = mode
  forEachFeature("onStabilityChanged")
  if not silent then
    message(ctx.settings.stability.names[mode] or mode, 3, "stability")
  end
end

function M.cycleStability()
  if ctx then
    M.setStability(cycle(ctx.settings.stability.order, ctx.stability))
  end
end

function M.toggleFeature(section)
  if not ctx or not ctx.settings[section] then
    return
  end
  local enabled = not ctx.settings[section].enabled
  ctx.settings[section].enabled = enabled
  config.setVehicleValue(ctx.modelKey, {section, "enabled"}, enabled)
  if not enabled then
    runFeature(section, "restore")
  end
  message(section .. ": " .. (enabled and "on" or "off"), 2, "toggle")
end

function M.reloadSettings()
  if not ctx then
    return
  end
  forEachFeature("restore")
  local profile, stability = ctx.profile, ctx.stability
  ctx.settings = config.load(ctx.modelKey)
  ctx.profile, ctx.stability = profile, stability
  forEachFeature("init")
  message("Settings reloaded", 2)
end

function M.getState()
  return ctx and {profile = ctx.profile, stability = ctx.stability, modelKey = ctx.modelKey}
end

-- Radial menu -----------------------------------------------------------------

local function onOff(section)
  return ctx.settings[section] and ctx.settings[section].enabled and "on" or "off"
end

local function menuEntry(title, priority, icon, action)
  return {
    title = title,
    priority = priority,
    icon = icon,
    originalActionInfo = {level = "/root/playerVehicle/vehicleFeatures/", uniqueID = "driveTech"},
    onSelect = function()
      action()
      return {"reload"}
    end
  }
end

local function registerMenu()
  if hasRegisteredMenu or not core_quickAccess then
    return
  end
  hasRegisteredMenu = true

  core_quickAccess.addEntry({
    level = "/root/playerVehicle/vehicleFeatures/",
    generator = function(entries)
      if ctx and ctx.settings.enabled then
        table.insert(entries, {title = "DriveTech", priority = 45, ["goto"] = "/root/playerVehicle/vehicleFeatures/driveTech/", icon = "raceFlag", uniqueID = "driveTech"})
      end
    end
  })

  core_quickAccess.addEntry({
    level = "/root/playerVehicle/vehicleFeatures/driveTech",
    generator = function(entries)
      if not ctx then
        return
      end
      local s = ctx.settings
      table.insert(entries, menuEntry("Profile: " .. (s.profiles.names[ctx.profile] or ctx.profile), 10, "arrowLargeUp", M.cycleProfile))
      table.insert(entries, menuEntry(s.stability.names[ctx.stability] or ctx.stability, 20, "arrowLargeDown", M.cycleStability))
      table.insert(entries, menuEntry("Launch Control: " .. onOff("launch"), 30, "raceFlag", function() M.toggleFeature("launch") end))
      table.insert(entries, menuEntry("Start-Stop: " .. onOff("startStop"), 40, "powerOnOff", function() M.toggleFeature("startStop") end))
      table.insert(entries, menuEntry("Auto Hold: " .. onOff("autoHold"), 50, "powerOnOff", function() M.toggleFeature("autoHold") end))
      table.insert(entries, menuEntry("Coasting: " .. onOff("coasting"), 60, "powerOnOff", function() M.toggleFeature("coasting") end))
      table.insert(entries, menuEntry("Shift logic: " .. onOff("shiftLogic"), 70, "powerOnOff", function() M.toggleFeature("shiftLogic") end))
      table.insert(entries, menuEntry("Throttle map: " .. onOff("pedalMap"), 75, "powerOnOff", function() M.toggleFeature("pedalMap") end))
      table.insert(entries, menuEntry("Reload settings", 80, "powerOnOff", M.reloadSettings))
    end
  })
end

-- Lifecycle -------------------------------------------------------------------

local function updateGFX(dt)
  if not ctx or not ctx.settings.enabled then
    return
  end

  local seated = playerInfo.anyPlayerSeated
  if seated ~= wasPlayerSeated then
    wasPlayerSeated = seated
    if seated then
      forEachFeature("onPlayerEntered")
    else
      forEachFeature("restore")
      applyConverter()
    end
  end
  if not seated then
    return
  end

  ctx.dt = dt
  ctx.throttleInput = math.min(math.max(input.throttle or 0, 0), 1)
  ctx.brakeInput = math.min(math.max(input.brake or 0, 0), 1)
  ctx.clutchInput = math.min(math.max(input.clutch or 0, 0), 1)
  ctx.speed = electrics.values.wheelspeed or 0
  ctx.gear = tostring(electrics.values.gear or "")
  -- automatic gear names are "D", "S3", "M2", "P", "N", "R"; gearMode keeps only the selector position
  local prefix = ctx.gear:sub(1, 1)
  ctx.gearMode = (ctx.isAutomatic and (prefix == "S" or prefix == "M")) and prefix or ctx.gear
  ctx.usesKeyboard = input.state and input.state.throttle and (input.state.throttle.filter == FILTER_KBD or input.state.throttle.filter == FILTER_KBD2)

  forEachFeature("update", dt)
  applyConverter()

  -- state for instrument clusters (e.g. the DriveTech F31 cluster)
  electrics.values.driveTechProfile = PROFILE_INDEX[ctx.profile] or 1
  electrics.values.driveTechStability = STABILITY_INDEX[ctx.stability] or 0
end

local function onReset()
  if not ctx then
    return
  end
  forEachFeature("restore")
  applyConverter()
  forEachFeature("onVehicleReset")
end

local function onExtensionLoaded()
  local ok, err = pcall(buildContext)
  if not ok then
    log("E", "driveTech", "Init failed, DriveTech stays inactive for this vehicle: " .. tostring(err))
    ctx = nil
    return
  end

  for _, name in ipairs(featureNames) do
    local loaded, module = pcall(require, "driveTech/features/" .. name)
    if loaded and type(module) == "table" then
      features[name] = module
    else
      log("E", "driveTech", "Could not load feature " .. name .. ": " .. tostring(module))
    end
  end
  forEachFeature("init")

  rawset(_G, "driveTech", M)
  registerMenu()
end

M.onExtensionLoaded = onExtensionLoaded
M.onReset = onReset
-- assigned statically: the extension system may cache hook functions at load time
M.updateGFX = updateGFX

return M
