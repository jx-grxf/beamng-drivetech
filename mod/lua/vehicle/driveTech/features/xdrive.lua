-- DriveTech feature: xDrive-like all-wheel drive.
--
-- Uses the vehicle's electronically clutched split shaft (e.g. ETK "Electrically
-- Clutched Torque Splitter"). Sets a rear-biased preload per stability mode and
-- locks the clutch while pulling away, like xDrive does below ~20 km/h.

local M = {}

local splitShaftLock = nil
local appliedRevision = -1
local appliedStability = nil
local launchLockActive = false

local function setLaunchLock(active)
  if active ~= launchLockActive then
    launchLockActive = active
    splitShaftLock.overrideMin = active and 1 or 0
  end
end

local function apply(ctx)
  local p = ctx.settings.xdrive[ctx.stability] or ctx.settings.xdrive.dsc
  splitShaftLock.setParameters({minimumLock = p.minimumLock, avDiffThreshold = p.avDiffThreshold})
  appliedRevision = ctx.driveModeRevision or 0
  appliedStability = ctx.stability
end

function M.init(ctx)
  splitShaftLock = controller.getController("electronicSplitShaftLock")
  if splitShaftLock and not splitShaftLock.setParameters then
    splitShaftLock = nil
  end
  ctx.hasXDrive = splitShaftLock ~= nil
  appliedRevision = -1
end

function M.update(ctx, dt)
  if not splitShaftLock or not ctx.settings.xdrive.enabled then
    return
  end
  if appliedRevision ~= (ctx.driveModeRevision or 0) or appliedStability ~= ctx.stability then
    apply(ctx)
  end

  local kmh = ctx.speed * 3.6
  local pullingAway = kmh < ctx.settings.xdrive.launchLockBelowKmh and ctx.throttleInput > 0.1 and ctx.brakeInput < 0.1 and electrics.values.parkingbrake <= 0
  setLaunchLock(pullingAway)
end

function M.restore(ctx)
  if not splitShaftLock then
    return
  end
  setLaunchLock(false)
  if appliedRevision >= 0 then
    splitShaftLock.setParameters({minimumLock = "default", avDiffThreshold = "default"})
    appliedRevision = -1
    appliedStability = nil
  end
end

return M
