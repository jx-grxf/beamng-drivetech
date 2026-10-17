-- DriveTech feature: shift logic for automatic and dual clutch gearboxes.
--
-- Stock BeamNG keeps the "driving aggression" high for seconds after lifting off,
-- so the car stays in a low gear at high rpm. A BMW in D upshifts quickly after
-- lift-off, while SPORT holds the gear and downshifts when braking hard.
-- This feature computes its own aggression per profile and hands it to the
-- vehicle controller via setAggressionOverride.

local M = {}

local min, max = math.min, math.max

local aggression = 0
local holdTimer = 0
local isOverriding = false

local function stopOverride()
  if isOverriding then
    controller.mainController.setAggressionOverride(nil)
    isOverriding = false
  end
end

local function supported(ctx)
  return ctx.isAutomatic and controller.mainController and controller.mainController.setAggressionOverride ~= nil
end

local function isAutomaticRange(gearMode)
  return gearMode == "D" or gearMode == "S"
end

function M.init(ctx)
  aggression = 0
  holdTimer = 0
  isOverriding = false
end

function M.update(ctx, dt)
  if not ctx.settings.shiftLogic.enabled or not supported(ctx) or not isAutomaticRange(ctx.gearMode) then
    stopOverride()
    return
  end

  local s = ctx.settings.shiftLogic
  local p = s.profiles[ctx.profile] or s.profiles.comfort
  local throttle = ctx.throttleInput
  local floor = p.floor
  if ctx.gearMode == "S" then
    floor = max(floor, s.sGearMinimumAggression)
  end

  if throttle >= s.kickdownThrottle then
    aggression = 1
    holdTimer = p.holdTime
  elseif throttle > 0.02 then
    local target = min(throttle * p.throttleGain, p.maxPartThrottle)
    if target > aggression then
      aggression = min(aggression + dt * 4, target)
    else
      aggression = max(aggression - dt * p.decay * 0.5, target)
    end
    holdTimer = p.holdTime
  elseif ctx.brakeInput > 0.3 then
    -- braking: keep the gear, and in sporty profiles go down for engine braking
    if p.brakeDownshift then
      aggression = max(aggression, min(ctx.brakeInput * 1.2, 1))
    end
    holdTimer = p.holdTime
  elseif s.cornerHoldLateralAccel > 0 and math.abs(sensors.gx2 or 0) > s.cornerHoldLateralAccel and ctx.profile ~= "eco" then
    -- cornering: keep the gear for the exit, like BMW's cornering detection
    holdTimer = max(holdTimer, 0.5)
  else
    holdTimer = max(holdTimer - dt, 0)
    if holdTimer <= 0 then
      aggression = max(aggression - dt * p.decay, 0)
    end
  end

  -- pulling away from standstill always starts calm unless the pedal says otherwise
  if ctx.speed < 1 and throttle < 0.5 then
    aggression = min(aggression, 0.3)
  end

  aggression = min(max(aggression, floor), 1)
  controller.mainController.setAggressionOverride(aggression)
  isOverriding = true
end

function M.restore(ctx)
  stopOverride()
end

function M.onVehicleReset(ctx)
  aggression = 0
  holdTimer = 0
end

return M
