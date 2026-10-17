-- DriveTech feature: Auto Hold.
--
-- After coming to a stop with the brake, the brakes stay applied when you let go
-- of the pedal. Pressing the throttle releases them. Only with the "realistic"
-- gearbox behaviour, because in arcade mode the brake pedal is also reverse.

local M = {}

local holding = false

local function release()
  if holding then
    electrics.values.brakeOverride = nil
    holding = false
  end
end

function M.init(ctx)
  holding = false
end

function M.update(ctx, dt)
  local s = ctx.settings.autoHold
  local realistic = controller.mainController.gearboxBehavior == "realistic"
  if not s.enabled or not realistic then
    release()
    return
  end

  if holding then
    local gearMode = ctx.gearMode
    if ctx.throttleInput > 0.05 or gearMode == "P" or gearMode == "N" or ctx.speed > 1 then
      release()
      return
    end
    electrics.values.brakeOverride = math.max(ctx.brakeInput, s.holdBrake)
  elseif ctx.speed < 0.1 and ctx.brakeInput > 0.1 and ctx.throttleInput <= 0.02 and ctx.gearMode ~= "P" and ctx.gearMode ~= "N" then
    holding = true
    electrics.values.brakeOverride = math.max(ctx.brakeInput, s.holdBrake)
    ctx.message("Auto Hold active", 2, "autoHold")
  end
end

function M.restore(ctx)
  release()
end

return M
