-- DriveTech scenario tests. Run with: python tests/run_tests.py
local mock = require("mock_beamng")

local tests = {}
local function test(name, fn) table.insert(tests, {name = name, fn = fn}) end

local function check(cond, msg)
  if not cond then error(msg or "check failed", 2) end
end

local function near(a, b, eps, msg)
  check(a ~= nil and math.abs(a - b) <= (eps or 1e-6), (msg or "") .. string.format(" (got %s, expected %s)", tostring(a), tostring(b)))
end

-- spawns the extension the way BeamNG does it for a vehicle
local function spawn(opts)
  local world = mock.setup(opts)
  local ext = dofile(MOD_ROOT .. "/lua/vehicle/extensions/auto/driveTech.lua")
  ext.onExtensionLoaded()
  return ext, world
end

local function frames(ext, n, dt)
  for _ = 1, n do ext.updateGFX(dt or 1 / 60) end
end

local function pedals(throttle, brake, clutch)
  input.throttle, input.brake, input.clutch = throttle or 0, brake or 0, clutch or 0
end

local function kmh(speed) electrics.values.wheelspeed = speed / 3.6 end

-------------------------------------------------------------------------------

test("loads on a typical automatic AWD vehicle without errors", function()
  local ext, world = spawn({awd = true})
  frames(ext, 10)
  check(#mock.errors() == 0, "errors: " .. table.concat(mock.errors(), "; "))
  check(driveTech ~= nil, "global API not registered")
  check(world.files["settings/driveTech.json"] ~= nil, "default settings file not written")
  check(#core_quickAccess.entries == 2, "radial menu not registered")
end)

test("vehicle without engine and gearbox (trailer/prop) stays quiet", function()
  local ext = spawn({engine = false, gearbox = false, cmu = false})
  pedals(1, 1)
  frames(ext, 30)
  check(#mock.errors() == 0, "errors: " .. table.concat(mock.errors(), "; "))
end)

test("electric / no-CMU manual car works", function()
  local ext = spawn({gearbox = "manualGearbox", cmu = false})
  pedals(0.5, 0)
  kmh(50)
  frames(ext, 30)
  check(#mock.errors() == 0, "errors: " .. table.concat(mock.errors(), "; "))
end)

test("launch control is blocked in COMFORT with DSC on (BMW rule)", function()
  local ext, world = spawn({})
  pedals(1, 1)
  frames(ext, 5)
  check(world.tempRevLimiterAV == nil, "limiter should not be set")
  check(mock.hasMessage("only in SPORT%+"), "hint message missing")
end)

test("launch control on torque converter: holds rpm, frees converter, launches", function()
  local ext, world = spawn({})
  driveTech.setProfile("sportPlus", true)
  pedals(1, 1)
  frames(ext, 60)
  near(world.tempRevLimiterAV / 0.104719755, 2500, 1, "diesel fallback launch rpm")
  near(world.devices.torqueConverter.impellerClutchCoef, 0.2, 1e-6, "converter hold coef")
  check(mock.hasMessage("Launch Control ready"), "armed message missing")
  pedals(1, 0)
  frames(ext, 1)
  check(world.tempRevLimiterAV == nil, "limiter must be released on brake release")
  frames(ext, 30)
  near(world.devices.torqueConverter.impellerClutchCoef, 1, 1e-6, "converter fully coupled again")
end)

test("launch control defers to the vehicle's own two-step", function()
  local ext, world = spawn({twoStep = true})
  driveTech.setStability("dtc", true)
  pedals(1, 1)
  frames(ext, 10)
  check(world.tempRevLimiterAV == nil, "own limiter must not be used when two-step exists")
  check(mock.hasMessage("2000"), "should report the two-step rpm")
end)

test("launch control on a manual: clutch in + throttle", function()
  local ext, world = spawn({gearbox = "manualGearbox", fuel = "gasoline", cmu = false})
  driveTech.setProfile("sportPlus", true)
  pedals(1, 0, 1)
  frames(ext, 5)
  near(world.tempRevLimiterAV / 0.104719755, 4000, 1, "petrol fallback launch rpm")
  pedals(1, 0, 0)
  frames(ext, 1)
  check(world.tempRevLimiterAV == nil, "limiter released on clutch release")
end)

test("shift logic: COMFORT upshifts soon after lift-off, SPORT holds", function()
  local ext, world = spawn({})
  kmh(80)
  pedals(1, 0)
  frames(ext, 30)
  near(world.aggression, 1, 1e-6, "kickdown = full aggression")
  pedals(0, 0)
  frames(ext, 90) -- 1.5 s
  check(world.aggression < 0.2, "comfort should drop aggression within 1.5 s, got " .. world.aggression)

  driveTech.setProfile("sport", true)
  pedals(1, 0)
  frames(ext, 30)
  pedals(0, 0)
  frames(ext, 90)
  check(world.aggression > 0.9, "sport should still hold after 1.5 s, got " .. world.aggression)
end)

test("shift logic: cornering keeps the gear", function()
  local ext, world = spawn({})
  driveTech.setProfile("comfort", true)
  kmh(80)
  pedals(1, 0)
  frames(ext, 30)
  pedals(0, 0)
  sensors.gx2 = 6
  frames(ext, 120)
  check(world.aggression > 0.9, "should hold while cornering, got " .. world.aggression)
  sensors.gx2 = 0
  frames(ext, 120)
  check(world.aggression < 0.2, "should release after the corner, got " .. world.aggression)
end)

test("shift logic: releases override in manual mode M", function()
  local ext, world = spawn({})
  kmh(60)
  pedals(0.5, 0)
  frames(ext, 10)
  check(world.aggression ~= nil, "override active in D")
  electrics.values.gear = "M3"
  frames(ext, 2)
  check(world.aggression == nil, "override must be cleared in M")
end)

test("start-stop: engine off at standstill, restarts on brake release", function()
  local ext, world = spawn({})
  kmh(0)
  pedals(0, 0.6)
  frames(ext, 70)
  check(world.ignition == false, "engine should be off")
  world.devices.mainEngine.outputAV1 = 0
  pedals(0, 0)
  frames(ext, 1)
  check(world.ignition == true and world.starter == true, "should restart with starter")
  world.devices.mainEngine.outputAV1 = 85
  frames(ext, 2)
  check(world.starter == false, "starter released once running")
end)

test("start-stop: disabled in SPORT and respects manual ignition off", function()
  local ext, world = spawn({})
  driveTech.setProfile("sport", true)
  pedals(0, 0.6)
  frames(ext, 120)
  check(world.ignition == nil, "no stop in sport")

  driveTech.setProfile("comfort", true)
  frames(ext, 70)
  check(world.ignition == false, "stops in comfort")
  electrics.values.ignitionLevel = 0 -- driver turned the key off
  pedals(0, 0)
  frames(ext, 1)
  check(world.ignition == false, "must not restart after the driver switched off")
end)

test("auto hold: holds after stop, releases on throttle", function()
  local ext, world = spawn({settingsFile = {autoHold = {enabled = true}}})
  kmh(0)
  pedals(0, 0.5)
  frames(ext, 2)
  pedals(0, 0)
  frames(ext, 2)
  near(electrics.values.brakeOverride, 0.6, 1e-6, "hold brake")
  pedals(0.3, 0)
  frames(ext, 1)
  check(electrics.values.brakeOverride == nil, "released on throttle")
end)

test("auto hold: inactive with arcade gearbox behaviour", function()
  local ext = spawn({settingsFile = {autoHold = {enabled = true}}, behavior = "arcade"})
  pedals(0, 0.5)
  frames(ext, 5)
  check(electrics.values.brakeOverride == nil, "no hold in arcade mode")
end)

test("ECO PRO coasting decouples the converter and recouples on throttle", function()
  local ext, world = spawn({})
  driveTech.setProfile("eco", true)
  kmh(90)
  pedals(0, 0)
  frames(ext, 60)
  near(world.devices.torqueConverter.impellerClutchCoef, 0, 1e-6, "coasting")
  check(mock.hasMessage("Coasting"), "coasting message")
  pedals(0.2, 0)
  frames(ext, 20)
  near(world.devices.torqueConverter.impellerClutchCoef, 1, 1e-6, "recoupled")
end)

test("coasting not below 50 km/h", function()
  local ext, world = spawn({})
  driveTech.setProfile("eco", true)
  kmh(40)
  frames(ext, 60)
  near(world.devices.torqueConverter.impellerClutchCoef, 1, 1e-6, "no coasting at 40")
end)

test("pedal map: ECO softer, SPORT+ sharper, kickdown always 100 %", function()
  local ext = spawn({})
  kmh(50)
  driveTech.setProfile("eco", true)
  pedals(0.5, 0)
  frames(ext, 120)
  local eco = electrics.values.throttleOverride
  driveTech.setProfile("sportPlus", true)
  frames(ext, 120)
  local sp = electrics.values.throttleOverride
  check(eco < 0.4 and sp > 0.6, string.format("eco %.2f / sport+ %.2f", eco, sp))
  driveTech.setProfile("eco", true)
  pedals(1, 0)
  frames(ext, 120)
  near(electrics.values.throttleOverride, 1, 1e-6, "kickdown")
end)

test("pedal map steps aside for cruise control", function()
  local ext = spawn({})
  pedals(0.5, 0)
  frames(ext, 10)
  electrics.values.throttleOverride = 0.33 -- cruise control takes over
  frames(ext, 5)
  near(electrics.values.throttleOverride, 0.33, 1e-6, "cruise value untouched")
end)

test("stability: DTC raises slip, OFF disables, DSC restores the drive mode", function()
  local ext, world = spawn({})
  local c = world.controllers
  driveTech.setStability("dtc")
  near(c.motorTorqueControl.last["tractionControl.wheelGroupSettings.mainEngine.slipThreshold"], 0.3, 1e-6, "dtc slip")
  driveTech.setStability("off")
  check(c.tractionControl.last.isEnabled == false and c.yawControl.last.isEnabled == false, "off disables TC/ESC")
  local before = #c.driveModes.setCalls
  driveTech.setStability("dsc")
  check(#c.driveModes.setCalls == before + 1, "dsc re-applies the vehicle drive mode")
end)

test("stability is re-applied when the vehicle drive mode changes from outside", function()
  local ext, world = spawn({})
  local c = world.controllers
  frames(ext, 1) -- player is seated
  driveTech.setStability("off")
  c.tractionControl.last.isEnabled = true -- vehicle drive mode overwrote it
  c.driveModes.current = "sport"
  frames(ext, 1)
  check(c.tractionControl.last.isEnabled == false, "DSC OFF restored on top")
  check(driveTech.getState().profile == "sport", "profile follows the vehicle mode")
end)

test("profile links the vehicle drive mode (SPORT+ -> sport+)", function()
  local ext, world = spawn({})
  driveTech.setProfile("sportPlus")
  check(world.controllers.driveModes.current == "sport+", "got " .. world.controllers.driveModes.current)
  driveTech.setProfile("eco")
  check(world.controllers.driveModes.current == "comfort", "eco maps to comfort")
end)

test("xDrive: params per stability mode and launch lock below 20 km/h", function()
  local ext, world = spawn({awd = true})
  local essl = world.controllers.electronicSplitShaftLock
  frames(ext, 1)
  near(essl.last.minimumLock, 0.4, 1e-6, "dsc preload")
  kmh(5)
  pedals(0.5, 0)
  frames(ext, 1)
  check(essl.overrideMin == 1, "locked while pulling away")
  kmh(40)
  frames(ext, 1)
  check(essl.overrideMin == 0, "unlocked above 20 km/h")
  driveTech.setStability("dtc", true)
  frames(ext, 1)
  near(essl.last.minimumLock, 0.3, 1e-6, "dtc preload")
end)

test("nothing is touched while no player sits in the vehicle (AI traffic)", function()
  local ext, world = spawn({seated = false, awd = true})
  kmh(80)
  pedals(1, 1)
  frames(ext, 60)
  check(world.aggression == nil and world.tempRevLimiterAV == nil and electrics.values.throttleOverride == nil, "AI vehicle modified")
  near(world.devices.torqueConverter.impellerClutchCoef, 1, 1e-6, "converter untouched")
end)

test("leaving the vehicle restores everything", function()
  local ext, world = spawn({})
  driveTech.setProfile("sportPlus", true)
  pedals(1, 1)
  frames(ext, 30)
  playerInfo.anyPlayerSeated = false
  frames(ext, 1)
  check(world.tempRevLimiterAV == nil, "limiter reset")
  near(world.devices.torqueConverter.impellerClutchCoef, 1, 1e-6, "converter reset")
  check(world.aggression == nil, "aggression override cleared")
  check(electrics.values.throttleOverride == nil, "throttle override cleared")
end)

test("a crashing feature is disabled and restored, the others keep working", function()
  local ext, world = spawn({})
  world.controllers.motorTorqueControl.setParameters = function() error("boom") end
  driveTech.setStability("dtc", true)
  kmh(80)
  pedals(1, 0)
  frames(ext, 10)
  check(#mock.errors() >= 1, "error should be logged")
  near(world.aggression, 1, 1e-6, "shift logic still running")
end)

test("toggling a feature persists per vehicle model", function()
  local ext, world = spawn({model = "etk800"})
  driveTech.toggleFeature("autoHold")
  local f = world.files["settings/driveTech.json"]
  check(f.vehicles.etk800.autoHold.enabled == true, "saved per vehicle")
end)

test("per-vehicle overrides from the settings file are applied", function()
  local ext, world = spawn({model = "etk800", settingsFile = {vehicles = {etk800 = {launch = {rpm = 3100, requireSportPlusOrDtc = false}}}}})
  pedals(1, 1)
  frames(ext, 5)
  near(world.tempRevLimiterAV / 0.104719755, 3100, 1, "override rpm")
end)

test("keyboard input arms launch control with partial pedals", function()
  local ext, world = spawn({})
  driveTech.setProfile("sportPlus", true)
  input.state.throttle.filter = FILTER_KBD
  pedals(0.5, 0.5)
  frames(ext, 2)
  check(world.tempRevLimiterAV ~= nil, "keyboard launch")
end)

test("exports profile, stability and auto-stop for the instrument cluster", function()
  local ext = spawn({})
  driveTech.setProfile("sportPlus", true)
  driveTech.setStability("off", true)
  frames(ext, 1)
  check(electrics.values.driveTechProfile == 3, "profile index " .. tostring(electrics.values.driveTechProfile))
  check(electrics.values.driveTechStability == 2, "stability index " .. tostring(electrics.values.driveTechStability))
  driveTech.setProfile("comfort", true)
  pedals(0, 0.6)
  frames(ext, 70)
  check(electrics.values.driveTechAutoStop == 1, "auto stop flag")
end)

test("radial menu entries build and their actions run", function()
  local ext = spawn({})
  local entries = {}
  core_quickAccess.entries[1].generator(entries)
  check(#entries == 1 and entries[1].title == "DriveTech", "top level entry")
  entries = {}
  core_quickAccess.entries[2].generator(entries)
  check(#entries >= 8, "sub menu entries: " .. #entries)
  for _, e in ipairs(entries) do e.onSelect() end
  check(#mock.errors() == 0, "errors: " .. table.concat(mock.errors(), "; "))
end)

-------------------------------------------------------------------------------

local passed, failed = 0, 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then
    passed = passed + 1
    print("PASS  " .. t.name)
  else
    failed = failed + 1
    print("FAIL  " .. t.name .. "\n      " .. tostring(err))
  end
end
print(string.format("\n%d passed, %d failed", passed, failed))
return failed
