-- DriveTech feature: ECO PRO coasting.
--
-- Torque converter automatics in D: when you lift off between minKmh and maxKmh
-- without braking, the engine is decoupled and idles while the car rolls freely.
-- Throttle or brake couples it again within a fraction of a second.

local M = {}

local coef = 1
local coasting = false

function M.init(ctx)
  coef = 1
  coasting = false
end

function M.update(ctx, dt)
  local s = ctx.settings.coasting
  if not ctx.converter then
    return
  end

  local kmh = ctx.speed * 3.6
  local wanted = s.enabled and s.profiles[ctx.profile] and ctx.gearMode == "D"
    and kmh >= s.minKmh and kmh <= s.maxKmh
    and ctx.throttleInput <= 0.01 and ctx.brakeInput <= 0.01

  if wanted then
    coef = math.max(coef - dt * 2, 0)
    if not coasting and coef <= 0 then
      coasting = true
      ctx.message("Coasting", 2, "coasting")
    end
  else
    coef = math.min(coef + dt * 4, 1)
    coasting = false
  end

  ctx.converterRequests.coasting = coef < 1 and coef or nil
  electrics.values.driveTechCoasting = coasting
end

function M.restore(ctx)
  coef = 1
  coasting = false
  ctx.converterRequests.coasting = nil
end

return M
