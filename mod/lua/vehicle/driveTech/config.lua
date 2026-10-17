-- DriveTech: configuration defaults, loading and saving.
--
-- Settings live in <BeamNG user folder>/settings/driveTech.json.
-- The file is created with all defaults on first run. Anything in
-- "vehicles.<model>" overrides the global values for that vehicle model only.

local M = {}

M.filePath = "settings/driveTech.json"
M.version = 1

M.defaults = {
  version = 1,
  enabled = true,
  showMessages = true,

  -- Driving experience control (ECO PRO / COMFORT / SPORT / SPORT+)
  profiles = {
    enabled = true,
    default = "comfort",
    order = {"eco", "comfort", "sport", "sportPlus"},
    -- Switch the vehicle's own drive modes along with the profile.
    -- First key that exists on the vehicle wins.
    linkVehicleDriveModes = true,
    vehicleDriveModeMap = {
      eco = {"eco", "ecoPro", "comfort", "normal"},
      comfort = {"comfort", "normal", "default"},
      sport = {"sport"},
      sportPlus = {"sport+", "sportPlus", "sport_plus", "track", "sport"}
    },
    names = {eco = "ECO PRO", comfort = "COMFORT", sport = "SPORT", sportPlus = "SPORT+"}
  },

  -- Stability control: "dsc" (vehicle stock), "dtc" (more slip), "off"
  stability = {
    enabled = true,
    default = "dsc",
    order = {"dsc", "dtc", "off"},
    names = {dsc = "DSC ON", dtc = "DTC", off = "DSC OFF"},
    dtc = {
      tcSlipThreshold = 0.3,
      tcMinimumThrottle = 0.35,
      brakeTcSlipThreshold = 0.3,
      yawSlipAngleThreshold = 0.2,
      yawAvThreshold = 1.0
    }
  },

  -- xDrive-like AWD clutch behaviour (vehicles with an electronic split shaft)
  xdrive = {
    enabled = true,
    dsc = {minimumLock = 0.4, avDiffThreshold = 3},
    dtc = {minimumLock = 0.3, avDiffThreshold = 6},
    off = {minimumLock = 0.2, avDiffThreshold = 10},
    -- fully lock the clutch when pulling away below this speed (km/h)
    launchLockBelowKmh = 20
  },

  -- Automatic / DCT shift logic (fixes "stays in gear at high rpm after lift-off")
  shiftLogic = {
    enabled = true,
    kickdownThrottle = 0.95,
    sGearMinimumAggression = 0.5,
    -- no upshift while cornering harder than this (m/s², 0 = off)
    cornerHoldLateralAccel = 3.5,
    profiles = {
      -- holdTime: s to keep the current aggression after lifting off
      -- decay: aggression drop per second after holdTime (higher = upshifts sooner)
      -- floor: minimum aggression (higher = later upshifts)
      -- maxPartThrottle: aggression cap below kickdown
      -- brakeDownshift: downshift for engine braking when braking hard
      eco = {holdTime = 0.2, decay = 2.5, floor = 0.0, maxPartThrottle = 0.55, throttleGain = 0.9, brakeDownshift = false},
      comfort = {holdTime = 0.5, decay = 1.5, floor = 0.0, maxPartThrottle = 0.85, throttleGain = 1.2, brakeDownshift = false},
      sport = {holdTime = 3.0, decay = 0.35, floor = 0.35, maxPartThrottle = 1.0, throttleGain = 1.333, brakeDownshift = true},
      sportPlus = {holdTime = 6.0, decay = 0.15, floor = 0.55, maxPartThrottle = 1.0, throttleGain = 1.5, brakeDownshift = true}
    }
  },

  -- Throttle response per profile.
  -- mapped = min(pedal ^ exponent * gain, maxPartThrottle); full pedal (kickdown) is always 100 %.
  -- riseRate / fallRate: how fast the mapped throttle may change (per second)
  pedalMap = {
    enabled = true,
    kickdownPedal = 0.97,
    profiles = {
      eco = {exponent = 1.6, gain = 0.9, maxPartThrottle = 0.8, riseRate = 1.5, fallRate = 4},
      comfort = {exponent = 1.2, gain = 1.0, maxPartThrottle = 1.0, riseRate = 3, fallRate = 6},
      sport = {exponent = 0.9, gain = 1.05, maxPartThrottle = 1.0, riseRate = 8, fallRate = 10},
      sportPlus = {exponent = 0.75, gain = 1.1, maxPartThrottle = 1.0, riseRate = 20, fallRate = 20}
    }
  },

  -- Launch control
  launch = {
    enabled = true,
    -- BMW: only in SPORT+ or with DTC / DSC OFF
    requireSportPlusOrDtc = true,
    -- "auto": use the vehicle's own two-step RPM if it has one, otherwise the value below
    rpm = "auto",
    fallbackRpmDiesel = 2500,
    fallbackRpmPetrol = 4000,
    -- torque converter automatics: load reduction while armed (0..1, lower = revs more freely)
    converterHoldCoef = 0.2,
    converterReleaseTime = 0.2
  },

  -- Auto Start-Stop
  startStop = {
    enabled = true,
    profiles = {eco = true, comfort = true, sport = false, sportPlus = false},
    stopDelay = 1.0,
    minBrake = 0.3
  },

  -- Auto Hold (keeps the brakes applied after stopping until you accelerate)
  autoHold = {
    enabled = false,
    holdBrake = 0.6
  },

  -- ECO PRO coasting: decouples the engine on lift-off (torque converter automatics)
  coasting = {
    enabled = true,
    profiles = {eco = true, comfort = false, sport = false, sportPlus = false},
    minKmh = 50,
    maxKmh = 160
  },

  -- Per vehicle model overrides, e.g. vehicles.etk800.launch.rpm = 2800
  vehicles = {}
}

local function deepMerge(target, source)
  for k, v in pairs(source) do
    if type(v) == "table" and type(target[k]) == "table" and v[1] == nil then
      deepMerge(target[k], v)
    else
      target[k] = deepcopy(v)
    end
  end
  return target
end

M.deepMerge = deepMerge

local fileData = nil

local function readFile()
  local ok, data = pcall(jsonReadFile, M.filePath)
  if ok and type(data) == "table" then
    return data
  end
  return nil
end

local function writeFile(data)
  local ok, err = pcall(jsonWriteFile, M.filePath, data, true)
  if not ok then
    log("W", "driveTech.config", "Could not write " .. M.filePath .. ": " .. tostring(err))
  end
end

-- Returns the merged settings for the given vehicle model.
function M.load(modelKey)
  fileData = readFile()
  if not fileData then
    fileData = deepcopy(M.defaults)
    writeFile(fileData)
  end

  local settings = deepMerge(deepcopy(M.defaults), fileData)
  settings.vehicles = nil
  local vehicleOverrides = (fileData.vehicles or {})[modelKey]
  if type(vehicleOverrides) == "table" then
    deepMerge(settings, vehicleOverrides)
  end
  return settings
end

-- Stores a single value for this vehicle model, e.g. setVehicleValue("etk800", {"autoHold", "enabled"}, true)
function M.setVehicleValue(modelKey, path, value)
  fileData = fileData or readFile() or deepcopy(M.defaults)
  fileData.vehicles = fileData.vehicles or {}
  local node = fileData.vehicles[modelKey] or {}
  fileData.vehicles[modelKey] = node
  for i = 1, #path - 1 do
    node[path[i]] = type(node[path[i]]) == "table" and node[path[i]] or {}
    node = node[path[i]]
  end
  node[path[#path]] = value
  writeFile(fileData)
end

return M
