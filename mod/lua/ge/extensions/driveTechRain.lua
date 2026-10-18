-- DriveTech rain: switches rain on any map, including wet grip on paved surfaces and aquaplaning.
-- Visuals use the level's own Precipitation object (one is spawned if the map has none),
-- grip is lowered by re-submitting the paved ground models with wet friction values.
-- Aquaplaning runs per vehicle (vehicle extension driveTechAquaplaning); this side tracks the
-- water film on the road and sends it to every vehicle.

local M = {}

local CLOUD_COVER = 2.0     -- 0..3, same scale as the environment app
local FOG_FACTOR = 3        -- multiplies the map's own fog
local MIN_FOG = 0.004       -- raw LevelInfo fogDensity
local APPLY_DELAY = 1.0     -- seconds after a level load, so the level's own environment setup runs first

-- stock maps ship their rain object with 0 drops; water is the film depth the road settles at
local INTENSITIES = {
  light  = {drops = 1500, water = 0.8},
  medium = {drops = 3000, water = 2.5},
  heavy  = {drops = 6000, water = 6.0},
}
local TREAD_DEPTHS = {8, 5, 3, 1.6}   -- mm: new, half worn, worn, legal minimum
local WATER_RISE = 0.08     -- mm/s, a fresh shower needs a while before the water stands on the road
local WATER_FALL = 0.04     -- mm/s, when the rain gets lighter
local WATER_SYNC_STEP = 0.05
local SETTINGS_FILE = 'settings/driveTechRain.json'

-- roughly 25 % less grip, like real wet asphalt (stock ASPHALT_WET only loses about 6 %)
local STATIC_FACTOR = 0.76
local SLIDING_FACTOR = 0.74
local WET_HYDRODYNAMIC = 0.0012
local WET_SURFACES = {
  ASPHALT = 'ASPHALT_WET', ASPHALT_OLD = 'ASPHALT_WET', ASPHALT_PREPPED = 'ASPHALT_WET',
  COBBLESTONE = true, RUMBLE_STRIP = true, KERB = true,
  METAL = true, METAL_TREAD = true, WOOD = true,
}
local GM_FIELDS = {
  'roughnessCoefficient', 'defaultDepth', 'staticFrictionCoefficient', 'slidingFrictionCoefficient',
  'hydrodynamicFriction', 'stribeckVelocity', 'strength', 'collisiontype', 'fluidDensity',
  'flowConsistencyIndex', 'flowBehaviorIndex', 'dragAnisotropy', 'skidMarks', 'shearStrength',
}
local SPAWNED_NAME = 'driveTech_rain'

local enabled = false
local pending = nil
local dry = nil   -- environment values from before the rain, restored when it stops
local settings = {aquaplaning = false, intensity = 'medium', tread = 8}
local raining = false     -- rain is actually applied in the current level
local water = 0           -- mm standing on the road
local sentWater = -1
local wetMaterialIds = {}

local function waterTarget()
  return raining and INTENSITIES[settings.intensity].water or 0
end

local function sendState()
  guihooks.trigger('DriveTechRainState', {
    enabled = enabled,
    aquaplaning = settings.aquaplaning,
    intensity = settings.intensity,
    tread = settings.tread,
    water = water,
    waterTarget = waterTarget(),
  })
end

local function loadSettings()
  local data = jsonReadFile(SETTINGS_FILE)
  if type(data) ~= 'table' then return end
  if type(data.aquaplaning) == 'boolean' then settings.aquaplaning = data.aquaplaning end
  if INTENSITIES[data.intensity] then settings.intensity = data.intensity end
  for _, t in ipairs(TREAD_DEPTHS) do
    if data.tread == t then settings.tread = t end
  end
end

local function saveSettings()
  jsonWriteFile(SETTINGS_FILE, settings, true)
end

-- Vehicles -----------------------------------------------------------------------

local function vehicleCommand()
  local effective = settings.aquaplaning and water or 0
  return string.format('if driveTechAquaplaning then driveTechAquaplaning.setWater(%.3f, %.2f, {%s}) end',
    effective, settings.tread, table.concat(wetMaterialIds, ','))
end

local function syncVehicles()
  sentWater = water
  be:queueAllObjectLua(vehicleCommand())
end

-- a vehicle that was just spawned or reloaded asks for the current state
local function syncVehicle(id)
  local veh = be:getObjectByID(id)
  if veh then veh:queueLuaCommand(vehicleCommand()) end
end

-- Rain ---------------------------------------------------------------------------

local function findRainObject()
  local fallback
  for _, name in ipairs(scenetree.findClassObjects('Precipitation') or {}) do
    local obj = scenetree.findObject(name)
    if obj then
      -- prefer the full-coverage rain over the single drops on the windscreen
      if obj:getField('dataBlock', 0) == 'rain_medium' then return obj end
      fallback = fallback or obj
    end
  end
  return fallback
end

local function spawnRainObject()
  local obj = createObject('Precipitation')
  obj:setField('dataBlock', 0, 'rain_medium')
  obj:setField('boxWidth', 0, '16')
  obj:setField('boxHeight', 0, '10')
  obj:setField('dropSize', 0, '1')
  obj:setField('splashSize', 0, '0.25')
  obj:setField('splashMS', 0, '80')
  obj:setField('minSpeed', 0, '0.4')
  obj:setField('maxSpeed', 0, '0.5')
  obj:setField('useTurbulence', 0, '1')
  obj:setField('useWind', 0, '1')
  obj:registerObject(SPAWNED_NAME)
  scenetree.MissionGroup:addObject(obj)
  return obj
end

local function setDrops(obj, drops)
  obj:setField('numDrops', 0, tostring(drops))
  obj:setField('numOfDrops', 0, tostring(drops))
  obj:postApply()
end

local function wetGroundModel(src, rename)
  local gm = ground_model()
  for _, field in ipairs(GM_FIELDS) do gm[field] = src[field] end
  gm.staticFrictionCoefficient = src.staticFrictionCoefficient * STATIC_FACTOR
  gm.slidingFrictionCoefficient = src.slidingFrictionCoefficient * SLIDING_FACTOR
  gm.hydrodynamicFriction = math.max(src.hydrodynamicFriction, WET_HYDRODYNAMIC)
  gm.skidMarks = false
  if type(rename) == 'string' then
    -- wet tyre sounds and spray
    local particles = require('particles')
    gm.collisiontype = particles.getOrAddMaterialIDByName(particles.getMaterialsParticlesTable(), rename)
  end
  return gm
end

local function wetRoads()
  local gms = core_environment.groundModels or {}
  local wet = {}
  local ids = {}
  for name, entry in pairs(gms) do
    local root = entry.isAlias and entry.parent or name
    local rule = WET_SURFACES[root]
    if rule and gms[root] then
      if not wet[root] then
        wet[root] = wetGroundModel(gms[root].cdata, rule)
        ids[tonumber(wet[root].collisiontype)] = true
      end
      be:setGroundModel(name, wet[root])
    end
  end
  -- the vehicles see these ids as contact material under the tyres
  wetMaterialIds = {}
  for id in pairs(ids) do table.insert(wetMaterialIds, id) end
end

local function startRain()
  local env = core_environment
  if not env then return end

  local obj = findRainObject() or spawnRainObject()
  dry = dry or {
    cloudCover = env.getCloudCover(),
    fogDensity = env.getFogDensity(),
    drops = tonumber(obj:getField('numDrops', 0)) or 0,
  }
  env.setCloudCover(CLOUD_COVER)
  env.setFogDensity(math.max((dry.fogDensity or 0) * FOG_FACTOR, MIN_FOG))
  setDrops(obj, INTENSITIES[settings.intensity].drops)
  wetRoads()
  raining = true
  syncVehicles()
  log('I', 'driveTechRain', 'rain on (' .. settings.intensity .. ')')
end

local function stopRain()
  raining = false
  water = 0
  syncVehicles()

  local env = core_environment
  if not env then return end

  local spawned = scenetree.findObject(SPAWNED_NAME)
  if spawned then
    spawned:delete()
  else
    local obj = findRainObject()
    if obj then setDrops(obj, dry and dry.drops or 0) end
  end
  if dry then
    if dry.cloudCover then env.setCloudCover(dry.cloudCover) end
    if dry.fogDensity then env.setFogDensity(dry.fogDensity) end
  end
  dry = nil
  env.reloadGroundModels()
  log('I', 'driveTechRain', 'rain off')
end

local function inLevel()
  return getMissionFilename() ~= ''
end

-- API (UI app, key binding) ------------------------------------------------------

local function setEnabled(on)
  enabled = on and true or false
  pending = nil
  if inLevel() then
    if enabled then startRain() else stopRain() end
  end
  sendState()
end

local function toggle()
  setEnabled(not enabled)
end

local function isEnabled()
  return enabled
end

local function setAquaplaning(on)
  settings.aquaplaning = on and true or false
  saveSettings()
  syncVehicles()
  sendState()
end

local function toggleAquaplaning()
  setAquaplaning(not settings.aquaplaning)
end

local function setIntensity(name)
  if not INTENSITIES[name] then return end
  settings.intensity = name
  saveSettings()
  if raining then
    local obj = findRainObject()
    if obj then setDrops(obj, INTENSITIES[name].drops) end
  end
  sendState()
end

local function setTread(mm)
  mm = tonumber(mm)
  for _, t in ipairs(TREAD_DEPTHS) do
    if mm and math.abs(mm - t) < 0.01 then
      settings.tread = t
      saveSettings()
      syncVehicles()
      break
    end
  end
  sendState()
end

-- Lifecycle ----------------------------------------------------------------------

-- a level load resets environment and ground models, so the rain is re-applied afterwards
local function onClientPostStartMission()
  dry = nil
  raining = false
  water = 0
  if enabled then pending = APPLY_DELAY end
end

local function onClientEndMission()
  pending = nil
  dry = nil
  raining = false
  water = 0
end

local function onUpdate(dtReal, dtSim)
  if pending then
    pending = pending - dtReal
    if pending <= 0 then
      pending = nil
      if enabled then startRain() end
    end
  end

  -- water builds up and drains in sim time, so pausing the game pauses it too
  local target = waterTarget()
  if water ~= target then
    local step = (target > water and WATER_RISE or WATER_FALL) * (dtSim or 0)
    if target > water then water = math.min(water + step, target) else water = math.max(water - step, target) end
    if math.abs(water - sentWater) >= WATER_SYNC_STEP or water == target then
      syncVehicles()
      sendState()
    end
  end
end

local function onExtensionLoaded()
  loadSettings()
end

M.setEnabled = setEnabled
M.toggle = toggle
M.isEnabled = isEnabled
M.setAquaplaning = setAquaplaning
M.toggleAquaplaning = toggleAquaplaning
M.setIntensity = setIntensity
M.setTread = setTread
M.syncVehicle = syncVehicle
M.requestState = sendState
M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
M.onClientEndMission = onClientEndMission
M.onUpdate = onUpdate

return M
