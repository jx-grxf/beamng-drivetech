-- DriveTech aquaplaning: each tyre loses grip on its own when water lifts it off the road.
-- Water depth, tread depth and the wet surfaces come from the GE extension driveTechRain;
-- grip is lowered on the tread nodes, the same way BeamNG handles a flat tyre.

local M = {}

local model = require("driveTech/aquaplaning")

local LIFT_RISE = 8         -- 1/s, the water wedge builds up in about 0.1 s
local LIFT_FALL = 5         -- 1/s, and needs a little longer to clear
local APPLY_STEP = 0.01     -- only re-submit node friction when grip changed by more than this
local UI_INTERVAL = 0.1     -- s
local RUBBER_MATERIAL = 4
local ATMOSPHERE = 101325   -- Pa

local water = 0             -- mm on the road, 0 = dry or aquaplaning off
local tread = 8             -- mm
local wetMaterials = {}
local tyres = nil
local active = false        -- some tyre is still lifted or not back at full grip
local uiTimer = 0

local function buildTyres()
  tyres = {}
  for _, wd in pairs(wheels.wheelRotators or {}) do
    if wd.hasTire and (wd.rotatorType or "wheel") == "wheel" then
      local nodes = {}
      for _, cid in pairs(wd.treadNodes or wd.nodes or {}) do
        local node = v.data.nodes[cid]
        if node then
          local f = type(node.frictionCoef) == "number" and node.frictionCoef or 1
          local s = type(node.slidingFrictionCoef) == "number" and node.slidingFrictionCoef or f
          table.insert(nodes, {cid = cid, f = f, s = s})
        end
      end
      if #nodes > 0 then
        table.insert(tyres, {wd = wd, nodes = nodes, lift = 0, grip = 1, depth = 0, critical = math.huge})
      end
    end
  end
end

local function pressureKpa(wd)
  local groups = v.data.pressureGroups
  if wd.pressureGroup and groups and groups[wd.pressureGroup] then
    local kpa = (obj:getGroupPressure(groups[wd.pressureGroup]) - ATMOSPHERE) / 1000
    if kpa > 20 then
      return kpa
    end
  end
  return model.DEFAULT_PRESSURE_KPA
end

local function groundMaterial(wd)
  local mat, mat2 = wd.contactMaterialID1, wd.contactMaterialID2
  if mat == RUBBER_MATERIAL then
    mat = mat2
  end
  return mat
end

local function setGrip(tyre, grip)
  if grip > 0.995 then
    grip = 1
  end
  if math.abs(grip - tyre.grip) < APPLY_STEP and (grip < 1 or tyre.grip == 1) then
    return
  end
  tyre.grip = grip
  for _, n in ipairs(tyre.nodes) do
    obj:setNodeFrictionSlidingCoefs(n.cid, n.f * grip, n.s * grip)
  end
end

local function sendUI(speedKmh)
  local data = {water = water, speed = speedKmh, wheels = {}, critical = math.huge}
  for _, tyre in ipairs(tyres) do
    data.wheels[tyre.wd.name or tostring(tyre.wd.cid)] = tyre.lift
    data.critical = math.min(data.critical, tyre.critical)
  end
  if data.critical == math.huge then
    data.critical = nil
  end
  guihooks.trigger("DriveTechAquaplaning", data)
end

local function updateGFX(dt)
  if not tyres or (water <= 0 and not active) then
    return
  end

  local speedKmh = (electrics.values.airspeed or 0) * 3.6
  local pos = obj:getPosition()
  active = false
  for _, tyre in ipairs(tyres) do
    local wd = tyre.wd
    local target = 0
    tyre.critical = math.huge
    if water > 0 and not wd.isTireDeflated and not wd.isBroken and wetMaterials[groundMaterial(wd)] then
      local p = obj:getNodePosition(wd.node1)
      tyre.depth = model.waterAt(pos.x + p.x, pos.y + p.y, water)
      tyre.critical = model.criticalSpeed(tyre.depth, tread, pressureKpa(wd), wd.tireWidth)
      target = model.lift(speedKmh, tyre.critical)
    end
    local rate = target > tyre.lift and LIFT_RISE or LIFT_FALL
    tyre.lift = tyre.lift + (target - tyre.lift) * math.min(rate * dt, 1)
    if tyre.lift < 0.002 then
      tyre.lift = 0
    end
    -- a flat tyre keeps the friction values beamstate gave it
    if not wd.isTireDeflated then
      setGrip(tyre, model.grip(tyre.lift))
    end
    active = active or tyre.lift > 0 or tyre.grip < 1
  end

  if playerInfo.firstPlayerSeated then
    uiTimer = uiTimer - dt
    if uiTimer <= 0 then
      uiTimer = UI_INTERVAL
      sendUI(speedKmh)
    end
  end
end

-- called by driveTechRain: water film in mm (0 = off), tread depth in mm, ids of the wet surfaces
local function setWater(waterMm, treadMm, materialIds)
  water = math.max(tonumber(waterMm) or 0, 0)
  tread = tonumber(treadMm) or tread
  if type(materialIds) == "table" then
    wetMaterials = {}
    for _, id in pairs(materialIds) do
      wetMaterials[id] = true
    end
  end
  if water > 0 then
    active = true
  end
end

local function onReset()
  -- the physics reset puts the node friction back to the jbeam values
  if tyres then
    for _, tyre in ipairs(tyres) do
      tyre.lift, tyre.grip, tyre.critical = 0, 1, math.huge
    end
  end
end

local function onExtensionLoaded()
  local ok, err = pcall(buildTyres)
  if not ok then
    log("E", "driveTechAquaplaning", "Init failed: " .. tostring(err))
    tyres = nil
    return
  end
  rawset(_G, "driveTechAquaplaning", M)
  -- ask the rain extension for the current water state
  obj:queueGameEngineLua("if driveTechRain then driveTechRain.syncVehicle(" .. tostring(objectId) .. ") end")
end

M.setWater = setWater
M.updateGFX = updateGFX
M.onReset = onReset
M.onExtensionLoaded = onExtensionLoaded

return M
