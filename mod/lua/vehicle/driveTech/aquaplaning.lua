-- Aquaplaning model: how much of a tyre's contact patch is lifted off the road by water.
-- Pure functions, no BeamNG API, so the model can be tested on its own.
--
-- Base is Horne's NASA formula for the speed at which a tyre fully aquaplanes,
-- V = 6.35 * sqrt(p[kPa]) km/h, scaled for water depth, tread depth and tyre width so that it
-- lands near published tyre tests: new tyres at 8 mm water around 85-90 km/h,
-- tyres at the 1.6 mm legal minimum around 60-65 km/h.

local M = {}

local min, max, sqrt, sin = math.min, math.max, math.sqrt, math.sin

M.DEFAULT_PRESSURE_KPA = 230
M.REF_WIDTH = 0.205        -- m, a 205 tyre
M.REF_WATER = 4            -- mm, water depth where the depth factor is 1
M.MIN_WATER = 0.3          -- mm, below this the tread clears the film completely
M.CALIBRATION = 1.12
M.PARTIAL_START = 0.65     -- partial aquaplaning starts at 65 % of the critical speed
M.FULL_AT = 1.05           -- and is complete just above it
M.MIN_GRIP = 0.08          -- a fully floating tyre still has a little grip from the water itself

local function clamp(x, lo, hi)
  return min(max(x, lo), hi)
end

-- km/h at which the tyre fully aquaplanes, math.huge if it never does
function M.criticalSpeed(waterMm, treadMm, pressureKpa, widthM)
  waterMm = waterMm or 0
  if waterMm <= M.MIN_WATER then
    return math.huge
  end
  local horne = 6.35 * sqrt(clamp(pressureKpa or M.DEFAULT_PRESSURE_KPA, 120, 400))
  local depthFactor = (M.REF_WATER / waterMm) ^ 0.3
  local treadFactor = 0.65 + 0.044 * clamp(treadMm or 8, 0, 9)
  local width = (widthM and widthM > 0.05) and widthM or M.REF_WIDTH
  local widthFactor = (M.REF_WIDTH / clamp(width, 0.1, 0.4)) ^ 0.25
  return horne * M.CALIBRATION * depthFactor * treadFactor * widthFactor
end

-- 0 = full contact, 1 = tyre floats on the water
function M.lift(speedKmh, criticalKmh)
  if criticalKmh == math.huge or criticalKmh <= 0 then
    return 0
  end
  local x = clamp((speedKmh / criticalKmh - M.PARTIAL_START) / (M.FULL_AT - M.PARTIAL_START), 0, 1)
  return x * x * (3 - 2 * x)
end

-- friction multiplier for the tread nodes
function M.grip(lift)
  return 1 - clamp(lift, 0, 1) * (1 - M.MIN_GRIP)
end

-- Water depth at a world position. Roads are not evenly wet: ruts and dips hold more water and
-- a few spots collect real puddles. Fixed pattern, so the same corner is always the deep one.
function M.waterAt(x, y, baseMm)
  if not baseMm or baseMm <= 0 then
    return 0
  end
  local ripple = (sin(x * 0.11 + y * 0.07) + sin(x * 0.043 - y * 0.091 + 1.7) + sin(y * 0.19 + 0.4)) / 3
  local puddle = (sin(x * 0.061 + 2.1) * sin(y * 0.053 + 0.6) + sin((x + y) * 0.029)) * 0.5
  local deep = max(puddle - 0.55, 0) / 0.45
  return baseMm * max(1 + 0.35 * ripple + 1.6 * deep * deep, 0.4)
end

return M
