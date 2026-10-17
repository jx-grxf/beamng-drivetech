-- DriveTech feature: driving profiles + DSC / DTC / DSC OFF.
--
-- Profiles optionally switch the vehicle's own drive modes (suspension, steering,
-- throttle maps defined by the vehicle). DSC uses the vehicle's stock settings,
-- DTC raises the slip thresholds, DSC OFF disables traction and yaw control.
-- Works on vehicles with the "drivingDynamics" electronics (CMU); others keep stock.

local M = {}

local driveModes, tractionControl, yawControl, motorTorqueControl, brakeControl
local motorGroups, brakeGroups = {}, {}
local lastVehicleModeKey = nil
local touchedControllers = false

local function groupKeys(ctrl)
  local keys = {}
  if ctrl and ctrl.getConfig then
    local ok, cfg = pcall(ctrl.getConfig)
    if ok and cfg and cfg.tractionControl and cfg.tractionControl.wheelGroupSettings then
      for k in pairs(cfg.tractionControl.wheelGroupSettings) do
        table.insert(keys, k)
      end
    end
  end
  return keys
end

local function hasCMU()
  return tractionControl ~= nil or yawControl ~= nil
end

local function currentVehicleMode()
  return driveModes and driveModes.getCurrentDriveModeKey and driveModes.getCurrentDriveModeKey() or nil
end

local function setVehicleMode(key)
  if driveModes and key and driveModes.getDriveModeData(key) then
    driveModes.setDriveMode(key)
    lastVehicleModeKey = currentVehicleMode()
    return true
  end
  return false
end

-- Re-applies the vehicle's own settings for its current drive mode (= stock DSC)
local function restoreStock()
  if not touchedControllers then
    return
  end
  touchedControllers = false
  local key = currentVehicleMode()
  if key then
    setVehicleMode(key)
  else
    if tractionControl then tractionControl.setParameters({isEnabled = true}) end
    if yawControl then yawControl.setParameters({isEnabled = true}) end
    local mtcParams = {["tractionControl.isEnabled"] = "default", ["yawControl.slipAngleThreshold"] = "default", ["yawControl.yawAvThreshold"] = "default"}
    for _, k in ipairs(motorGroups) do
      mtcParams["tractionControl.wheelGroupSettings." .. k .. ".slipThreshold"] = "default"
      mtcParams["tractionControl.wheelGroupSettings." .. k .. ".minimumThrottleLimit"] = "default"
    end
    if motorTorqueControl then motorTorqueControl.setParameters(mtcParams) end
    local bcParams = {["tractionControl.isEnabled"] = "default", ["yawControl.slipAngleThreshold"] = "default", ["yawControl.yawAvThreshold"] = "default"}
    for _, k in ipairs(brakeGroups) do
      bcParams["tractionControl.wheelGroupSettings." .. k .. ".slipThreshold"] = "default"
    end
    if brakeControl then brakeControl.setParameters(bcParams) end
  end
end

local function applyStability(ctx)
  if not hasCMU() or not ctx.settings.stability.enabled then
    return
  end

  if ctx.stability == "dsc" then
    restoreStock()
  elseif ctx.stability == "dtc" then
    local p = ctx.settings.stability.dtc
    if tractionControl then tractionControl.setParameters({isEnabled = true}) end
    if yawControl then yawControl.setParameters({isEnabled = true}) end
    if motorTorqueControl then
      local params = {["tractionControl.isEnabled"] = true, ["yawControl.slipAngleThreshold"] = p.yawSlipAngleThreshold, ["yawControl.yawAvThreshold"] = p.yawAvThreshold}
      for _, k in ipairs(motorGroups) do
        params["tractionControl.wheelGroupSettings." .. k .. ".slipThreshold"] = p.tcSlipThreshold
        params["tractionControl.wheelGroupSettings." .. k .. ".minimumThrottleLimit"] = p.tcMinimumThrottle
      end
      motorTorqueControl.setParameters(params)
    end
    if brakeControl then
      local params = {["tractionControl.isEnabled"] = true, ["yawControl.slipAngleThreshold"] = p.yawSlipAngleThreshold, ["yawControl.yawAvThreshold"] = p.yawAvThreshold}
      for _, k in ipairs(brakeGroups) do
        params["tractionControl.wheelGroupSettings." .. k .. ".slipThreshold"] = p.brakeTcSlipThreshold
      end
      brakeControl.setParameters(params)
    end
    touchedControllers = true
  elseif ctx.stability == "off" then
    if tractionControl then tractionControl.setParameters({isEnabled = false}) end
    if yawControl then yawControl.setParameters({isEnabled = false}) end
    touchedControllers = true
  end
  ctx.driveModeRevision = (ctx.driveModeRevision or 0) + 1
end

local function profileForVehicleMode(ctx, key)
  local map = ctx.settings.profiles.vehicleDriveModeMap
  local current = map[ctx.profile]
  if current then
    for _, k in ipairs(current) do
      if driveModes.getDriveModeData(k) then
        if k == key then
          return ctx.profile
        end
        break
      end
    end
  end
  for _, profile in ipairs({"sportPlus", "sport", "comfort", "eco"}) do
    for _, k in ipairs(map[profile] or {}) do
      if driveModes.getDriveModeData(k) then
        if k == key then
          return profile
        end
        break
      end
    end
  end
end

local function linkProfile(ctx)
  local p = ctx.settings.profiles
  if not (p.enabled and p.linkVehicleDriveModes and driveModes) then
    return
  end
  for _, key in ipairs(p.vehicleDriveModeMap[ctx.profile] or {}) do
    if key == currentVehicleMode() and driveModes.getDriveModeData(key) then
      return
    end
    if setVehicleMode(key) then
      return
    end
  end
end

function M.init(ctx)
  driveModes = controller.getController("driveModes")
  tractionControl = controller.getController("tractionControl")
  yawControl = controller.getController("yawControl")
  motorTorqueControl = controller.getController("motorTorqueControl")
  brakeControl = controller.getController("brakeControl")
  motorGroups = groupKeys(motorTorqueControl)
  brakeGroups = groupKeys(brakeControl)
  lastVehicleModeKey = currentVehicleMode()
  ctx.hasStabilityControl = hasCMU()
  ctx.driveModeRevision = ctx.driveModeRevision or 0
end

function M.onPlayerEntered(ctx)
  linkProfile(ctx)
  applyStability(ctx)
end

function M.onProfileChanged(ctx)
  linkProfile(ctx)
  applyStability(ctx)
end

function M.onStabilityChanged(ctx)
  applyStability(ctx)
end

function M.onVehicleReset(ctx)
  lastVehicleModeKey = currentVehicleMode()
  applyStability(ctx)
end

function M.update(ctx, dt)
  if not driveModes then
    return
  end
  -- The vehicle's drive mode was changed from outside (vanilla ESC key, radial menu):
  -- follow it with the profile and put our stability settings back on top.
  local key = currentVehicleMode()
  if key ~= lastVehicleModeKey then
    lastVehicleModeKey = key
    if ctx.settings.profiles.enabled and ctx.settings.profiles.linkVehicleDriveModes then
      local profile = profileForVehicleMode(ctx, key)
      if profile and profile ~= ctx.profile then
        ctx.profile = profile
      end
    end
    if ctx.stability ~= "dsc" then
      touchedControllers = false
      applyStability(ctx)
    else
      ctx.driveModeRevision = (ctx.driveModeRevision or 0) + 1
    end
  end
end

function M.restore(ctx)
  if ctx.stability ~= "dsc" then
    restoreStock()
  end
end

return M
