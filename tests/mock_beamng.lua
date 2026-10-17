-- Minimal stand-ins for the BeamNG vehicle Lua API used by DriveTech.
-- Each call to mock.setup() builds a fresh vehicle; options pick the hardware.

local mock = {}

function mock.setup(opts)
  opts = opts or {}
  local world = {messages = {}, logs = {}, files = {}, calls = {}}
  mock.world = world

  _G.FILTER_KBD, _G.FILTER_PAD, _G.FILTER_DIRECT, _G.FILTER_KBD2 = 0, 1, 2, 3
  _G.nop = function() end
  _G.log = function(level, tag, msg)
    table.insert(world.logs, {level = level, tag = tag, msg = msg})
  end
  _G.deepcopy = function(o)
    if type(o) ~= "table" then return o end
    local r = {}
    for k, v in pairs(o) do r[k] = deepcopy(v) end
    return r
  end
  _G.jsonReadFile = function(name) return deepcopy(world.files[name]) end
  _G.jsonWriteFile = function(name, data) world.files[name] = deepcopy(data) return true end
  if opts.settingsFile then world.files["settings/driveTech.json"] = opts.settingsFile end

  _G.guihooks = {message = function(text, duration, id) table.insert(world.messages, tostring(text)) end}
  _G.playerInfo = {anyPlayerSeated = opts.seated ~= false}
  _G.sensors = {gx2 = 0}
  _G.v = {config = {mainPartName = opts.model or "etk800"}}

  _G.electrics = {values = {wheelspeed = 0, gear = "D", ignitionLevel = 2, parkingbrake = 0, throttle = 0, brake = 0, gearIndex = 1}}
  _G.input = {throttle = 0, brake = 0, clutch = 0, state = {throttle = {filter = FILTER_DIRECT}}}

  -- powertrain devices
  local devices = {}
  if opts.engine ~= false then
    devices.mainEngine = {
      type = "combustionEngine", outputAV1 = 85, idleAV = 80, starterMaxAV = 100, ignitionCoef = 1,
      isStalled = false, requiredEnergyType = opts.fuel or "diesel", maxAV = 600,
      setTempRevLimiter = function(self, av) world.tempRevLimiterAV = av end,
      resetTempRevLimiter = function(self) world.tempRevLimiterAV = nil end
    }
  end
  if opts.gearbox ~= false then
    devices.gearbox = {type = opts.gearbox or "automaticGearbox", gearIndex = 1}
  end
  if (opts.gearbox or "automaticGearbox") == "automaticGearbox" and opts.converter ~= false and opts.gearbox ~= false then
    devices.torqueConverter = {type = "torqueConverter", impellerClutchCoef = 1}
  end
  _G.powertrain = {
    getDevice = function(name) return devices[name] end,
    getDevices = function() return devices end
  }
  world.devices = devices

  -- controllers
  local controllers = {}
  local function recorder(name, extra)
    local c = extra or {}
    c.params = {}
    c.setParameters = function(p)
      table.insert(c.params, deepcopy(p))
      for k, val in pairs(p) do c.last = c.last or {}; c.last[k] = val end
    end
    controllers[name] = c
    return c
  end
  if opts.cmu ~= false then
    recorder("tractionControl")
    recorder("yawControl")
    local groupCfg = function() return {tractionControl = {wheelGroupSettings = {mainEngine = {}}}} end
    recorder("motorTorqueControl", {getConfig = groupCfg})
    recorder("brakeControl", {getConfig = groupCfg})
  end
  if opts.driveModes ~= false and opts.cmu ~= false then
    local modes = {comfort = true, sport = true, ["sport+"] = true, off = true}
    local dm = {current = "comfort", setCalls = {}}
    dm.getCurrentDriveModeKey = function() return dm.current end
    dm.getDriveModeData = function(k) return modes[k] and {key = k} or nil end
    dm.setDriveMode = function(k) dm.current = k; table.insert(dm.setCalls, k) end
    controllers.driveModes = dm
  end
  if opts.awd then
    recorder("electronicSplitShaftLock", {overrideMin = 0, overrideMax = 1})
  end
  if opts.twoStep then
    local ts = {state = "idle", rpm = 2000}
    ts.serialize = function() return {state = ts.state, rpm = ts.rpm} end
    ts.setParameters = function(p) if p.launchRPM then ts.rpm = p.launchRPM end end
    controllers.twoStepLaunch = ts
  end
  world.controllers = controllers

  local main = {gearboxBehavior = opts.behavior or "realistic"}
  main.setAggressionOverride = function(a) world.aggression = a end
  main.setEngineIgnition = function(on) world.ignition = on; table.insert(world.calls, "ignition:" .. tostring(on)) end
  main.setStarter = function(on) world.starter = on; table.insert(world.calls, "starter:" .. tostring(on)) end
  _G.controller = {
    mainController = main,
    getController = function(name) return controllers[name] end
  }

  _G.core_quickAccess = {entries = {}, addEntry = function(e) table.insert(core_quickAccess.entries, e) end}
  _G.driveTech = nil

  -- fresh module state for every scenario
  for name in pairs(package.loaded) do
    if name:find("^driveTech") then package.loaded[name] = nil end
  end
  return world
end

function mock.lastMessage()
  return mock.world.messages[#mock.world.messages]
end

function mock.hasMessage(pattern)
  for _, m in ipairs(mock.world.messages) do
    if m:find(pattern) then return true end
  end
  return false
end

function mock.errors()
  local r = {}
  for _, l in ipairs(mock.world.logs) do
    if l.level == "E" then table.insert(r, l.msg) end
  end
  return r
end

return mock
