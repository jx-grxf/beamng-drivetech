-- DriveTech feature: Auto Start-Stop.
--
-- Automatic / DCT in D: after standing still on the brake for a moment the engine
-- switches off, and starts again as soon as the brake is released (or the
-- throttle is pressed, or the selector leaves D). Disabled in SPORT profiles.

local M = {}

local stopTimer = 0
local engineStopped = false
local startingTimer = nil

local function engineRunning(ctx)
  local e = ctx.engine
  return e.outputAV1 > e.idleAV * 0.5 and (e.ignitionCoef or 1) > 0 and not e.isStalled
end

local function restartEngine(ctx)
  engineStopped = false
  -- the driver switched the ignition off meanwhile: leave the engine off
  if (electrics.values.ignitionLevel or 2) < 2 then
    return
  end
  controller.mainController.setEngineIgnition(true)
  controller.mainController.setStarter(true)
  startingTimer = 0
end

local function supported(ctx)
  return ctx.engine and ctx.isAutomatic and ctx.engine.starterMaxAV ~= nil and controller.mainController.setEngineIgnition ~= nil
end

function M.init(ctx)
  stopTimer = 0
  engineStopped = false
  startingTimer = nil
end

function M.update(ctx, dt)
  if not supported(ctx) then
    return
  end
  local s = ctx.settings.startStop

  if startingTimer then
    startingTimer = startingTimer + dt
    if ctx.engine.outputAV1 >= ctx.engine.idleAV * 0.9 or startingTimer > 2 then
      controller.mainController.setStarter(false)
      startingTimer = nil
    end
    return
  end

  local allowed = s.enabled and s.profiles[ctx.profile] and not electrics.values.driveTechLaunchArmed
  electrics.values.driveTechAutoStop = engineStopped and 1 or 0

  if engineStopped then
    if not allowed or ctx.brakeInput < 0.15 or ctx.throttleInput > 0.02 or ctx.gearMode ~= "D" then
      restartEngine(ctx)
    end
    return
  end

  if allowed and ctx.gearMode == "D" and ctx.speed < 0.3 and ctx.brakeInput >= s.minBrake and ctx.throttleInput <= 0.02 and engineRunning(ctx) then
    stopTimer = stopTimer + dt
    if stopTimer >= s.stopDelay then
      stopTimer = 0
      engineStopped = true
      controller.mainController.setEngineIgnition(false)
      ctx.message("Auto Start-Stop: engine off", 2, "startStop")
    end
  else
    stopTimer = 0
  end
end

function M.restore(ctx)
  electrics.values.driveTechAutoStop = 0
  if engineStopped then
    restartEngine(ctx)
  end
  stopTimer = 0
end

function M.onVehicleReset(ctx)
  engineStopped = false
  startingTimer = nil
  stopTimer = 0
end

return M
