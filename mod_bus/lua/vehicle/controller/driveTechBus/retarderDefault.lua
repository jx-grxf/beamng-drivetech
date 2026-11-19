-- DriveTech Bus: switches the retarder to its configured mode when the bus spawns.
-- BeamNG's retarderControl always starts in "off"; a bus driver expects it armed.
local M = {}
M.type = "auxiliary"

local defaultMode = "auto"

local function init(jbeamData)
  defaultMode = jbeamData.defaultMode or "auto"
end

local function initLastStage()
  local retarderControl = controller.getController("retarderControl")
  if retarderControl and retarderControl.setRetarderMode then
    retarderControl.setRetarderMode(defaultMode)
  end
end

M.init = init
M.initLastStage = initLastStage

return M
