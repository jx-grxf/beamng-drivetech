-- DriveTech feature: launch control.
--
-- Automatic / DCT: hold the brake, floor the throttle, release the brake.
-- Manual: clutch in, floor the throttle, drop the clutch.
-- Holds the engine at the launch rpm while armed. On torque converter automatics
-- the converter load is reduced while armed, otherwise the converter stalls the
-- engine below the launch rpm. If the vehicle has its own two-step controller,
-- that one keeps doing the rpm limiting and this feature only adds the rest.

local M = {}

local rpmToAV = 0.104719755

local state = "idle" -- idle, armed, launching
local converterCoef = 1
local twoStep = nil
local usingOwnLimiter = false
local hintShown = false

local function twoStepActive()
  if not twoStep or not twoStep.serialize then
    return false, nil
  end
  local ok, data = pcall(twoStep.serialize)
  if ok and data and data.state ~= "deactivated" then
    return true, data.rpm
  end
  return false, nil
end

local function launchRPM(ctx)
  local s = ctx.settings.launch
  local hasTwoStep, twoStepRPM = twoStepActive()
  if type(s.rpm) == "number" then
    return s.rpm
  end
  if hasTwoStep and twoStepRPM then
    return twoStepRPM
  end
  return ctx.isDiesel and s.fallbackRpmDiesel or s.fallbackRpmPetrol
end

local function releaseLimiter(ctx)
  if usingOwnLimiter then
    ctx.engine:resetTempRevLimiter()
    usingOwnLimiter = false
  end
end

local function isAllowed(ctx)
  if not ctx.settings.launch.requireSportPlusOrDtc then
    return true
  end
  return ctx.profile == "sportPlus" or ctx.stability ~= "dsc"
end

local function usesClutchPedal(ctx)
  return ctx.gearboxType == "manualGearbox"
end

local function armConditions(ctx)
  local high = ctx.usesKeyboard and 0.2 or 0.8
  local slowEnough = ctx.speed <= (ctx.usesKeyboard and 2 or 0.5)
  local throttleHigh = ctx.throttleInput >= high
  local holding
  if usesClutchPedal(ctx) then
    holding = ctx.clutchInput >= 0.6 and (electrics.values.gearIndex or 0) >= 1
  else
    holding = ctx.brakeInput >= high and (ctx.gearbox.gearIndex or 0) >= 1
  end
  return slowEnough and throttleHigh and holding
end

function M.init(ctx)
  twoStep = controller.getController("twoStepLaunch")
  state = "idle"
  converterCoef = 1
  usingOwnLimiter = false
end

function M.update(ctx, dt)
  local s = ctx.settings.launch
  if not s.enabled or not ctx.engine or not ctx.gearbox then
    M.restore(ctx)
    return
  end

  if state == "idle" then
    if armConditions(ctx) then
      if isAllowed(ctx) then
        state = "armed"
        hintShown = false
        local rpm = launchRPM(ctx)
        local hasTwoStep = twoStepActive()
        if hasTwoStep then
          if type(s.rpm) == "number" then
            twoStep.setParameters({launchRPM = rpm})
          end
        else
          ctx.engine:setTempRevLimiter(rpm * rpmToAV)
          usingOwnLimiter = true
        end
        ctx.message(string.format("Launch Control ready (%d rpm) - release the %s!", rpm, usesClutchPedal(ctx) and "clutch" or "brake"), 3, "launch")
      elseif not hintShown then
        hintShown = true
        ctx.message("Launch Control only in SPORT+ or with DTC / DSC OFF", 3, "launch")
      end
    end
  elseif state == "armed" then
    local released = usesClutchPedal(ctx) and ctx.clutchInput < 0.3 or (not usesClutchPedal(ctx) and ctx.brakeInput <= 0.02)
    if ctx.throttleInput <= 0.05 or (ctx.gearbox.gearIndex or 0) < 1 then
      state = "idle"
      releaseLimiter(ctx)
    elseif released then
      state = "launching"
      releaseLimiter(ctx)
      ctx.message("Launch!", 2, "launch")
    end
  elseif state == "launching" then
    if converterCoef >= 1 or not ctx.converter then
      state = "idle"
    end
  end

  if ctx.converter then
    if state == "armed" then
      converterCoef = math.max(converterCoef - dt * 4, s.converterHoldCoef)
    else
      converterCoef = math.min(converterCoef + dt / math.max(s.converterReleaseTime, 0.01), 1)
    end
    ctx.converterRequests.launch = converterCoef < 1 and converterCoef or nil
  end

  electrics.values.driveTechLaunchArmed = state == "armed"
end

function M.restore(ctx)
  if ctx.engine then
    releaseLimiter(ctx)
  end
  state = "idle"
  converterCoef = 1
  ctx.converterRequests.launch = nil
end

return M
