-- DriveTech feature: throttle response per profile.
--
-- Maps the pedal through a curve per profile (ECO PRO soft and progressive,
-- SPORT+ sharp) and limits how fast the mapped throttle may rise. The pedal end
-- (kickdown) always gives full throttle. Uses electrics.values.throttleOverride,
-- and steps aside whenever something else (cruise control, scripts) uses it.

local M = {}

local lastWritten = nil
local mapped = 0

local function release()
  if lastWritten ~= nil and electrics.values.throttleOverride == lastWritten then
    electrics.values.throttleOverride = nil
  end
  lastWritten = nil
end

function M.init(ctx)
  lastWritten = nil
  mapped = 0
end

function M.update(ctx, dt)
  local s = ctx.settings.pedalMap
  local p = s.profiles[ctx.profile]
  if not s.enabled or not p or not ctx.engine then
    release()
    return
  end

  local current = electrics.values.throttleOverride
  if current ~= nil and current ~= lastWritten then
    -- someone else controls the throttle right now
    lastWritten = nil
    mapped = current
    return
  end

  local pedal = ctx.throttleInput
  local target
  if pedal >= s.kickdownPedal then
    target = 1
  else
    target = math.min((pedal ^ p.exponent) * p.gain, p.maxPartThrottle)
  end

  if target > mapped then
    mapped = math.min(mapped + dt * p.riseRate, target)
  else
    mapped = math.max(mapped - dt * p.fallRate, target)
  end

  electrics.values.throttleOverride = mapped
  lastWritten = mapped
end

function M.restore(ctx)
  release()
  mapped = 0
end

return M
