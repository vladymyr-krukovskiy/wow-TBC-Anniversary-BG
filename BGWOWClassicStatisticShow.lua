local ADDON_NAME = "BGWOWClassicStatisticShow"

local battlegroundDataDefault = {
  killingBlows = 0,
  honorableKills = 0,
  deaths = 0,
  honorGained = 0
}

local battlegroundDataCells = {
  killingBlows = nil,
  honorableKills = nil,
  deaths = nil,
  honorGained = nil
}

-- Frame template options exposed in settings.
-- 1. GlowBoxTemplate
-- 2. InsetFrameTemplate
-- 3. InsetFrameTemplate3
-- 4. TranslucentFrameTemplate
local frameTemplates = {
  "GlowBoxTemplate",
  "InsetFrameTemplate",
  "InsetFrameTemplate3",
  "TranslucentFrameTemplate"
}

local DEFAULT_FRAME_TEMPLATE = frameTemplates[1]
local DEFAULT_FRAME_SCALE = 1

local function IsFrameTemplateValid(templateName)
  for _, name in ipairs(frameTemplates) do
    if name == templateName then
      return true
    end
  end
  return false
end

-- Saved settings with defaults.
-- Must run after SavedVariables are loaded (PLAYER_LOGIN), not at file load.
local function InitDB()
  BGWOWClassicStatisticShowDB = BGWOWClassicStatisticShowDB or {}
  local db = BGWOWClassicStatisticShowDB
  if not IsFrameTemplateValid(db.frameTemplate) then
    db.frameTemplate = DEFAULT_FRAME_TEMPLATE
  end
  if db.frameScale == nil then
    db.frameScale = DEFAULT_FRAME_SCALE
  end
  if db.showOutsideBG == nil then
    db.showOutsideBG = true
  end
end

local templateFrame = nil
local header = nil
local factionIcon = nil
local classIcon = nil
local BuildUI = nil
local playerName = nil
local playerClass = nil
local optionsPanelCreated = false

-- Create the main stats frame using the selected template.
local function CreateShadowOverlayFrame(option, name, parent, templateName)
  local frame = CreateFrame(option, name, parent, templateName)
  frame:SetSize(300, 100)   -- Frame size.
  frame:SetPoint("CENTER") -- Default position.

  return frame
end


-- Pull player stats from the battleground scoreboard.
local function getPlayerData()
  local numScores = GetNumBattlefieldScores()

  for i = 1, numScores do
    local name, killingBlows, honorableKills, deaths, honorGained = GetBattlefieldScore(i);

    if (name == playerName and battlegroundDataCells['killingBlows'] ~= nil) then
        battlegroundDataCells['killingBlows']:SetText(killingBlows)
        battlegroundDataCells['honorableKills']:SetText(honorableKills)
        battlegroundDataCells['deaths']:SetText(deaths)
        battlegroundDataCells['honorGained']:SetText(honorGained)
      break
    end
  end
end

local scoreTicker = nil

-- Periodically refresh scoreboard data in BG.
local function StartScoreTicker()
  if scoreTicker then
    return
  end

  scoreTicker = C_Timer.NewTicker(3, function()
    RequestBattlefieldScoreData()
  end)
end

-- Stop periodic scoreboard updates outside BG.
local function StopScoreTicker()
  if not scoreTicker then
    return
  end

  scoreTicker:Cancel()
  scoreTicker = nil
end

-- Build the stats table inside the frame.
local function CreateTable(parent)
  -- Column headers.
  local columnTitles = { "Kills", "Honorable", "Deaths", "Honor" }
  local columnWidth = 60
  local rowHeight = 20
  local startY = -1

  -- Create header labels.
  for i, title in ipairs(columnTitles) do
    local headerText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerText:SetPoint("CENTER", parent, "CENTER", (i - 1) * columnWidth - 90, startY)
    headerText:SetText(title)
    headerText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
  end

  -- Create table cells (single row).
  for i = 1, 1 do
    for j = 1, #columnTitles do
      local cell = CreateFrame("Frame", nil, parent)
      cell:SetSize(columnWidth, rowHeight)
      cell:SetPoint("CENTER", parent, "CENTER", (j - 1) * columnWidth - 90, startY - i * rowHeight + 5)
      -- Cell text.
      local cellText = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      cellText:SetPoint("CENTER")

      -- Seed with default values and store references.
      if j == 1 then
        cellText:SetText(battlegroundDataDefault.killingBlows)
        battlegroundDataCells['killingBlows'] = cellText;
      elseif j == 2 then
        cellText:SetText(battlegroundDataDefault.honorableKills)
        battlegroundDataCells['honorableKills'] = cellText;
      elseif j == 3 then
        cellText:SetText(battlegroundDataDefault.deaths)
        battlegroundDataCells['deaths'] = cellText;
      elseif j == 4 then
        cellText:SetText(battlegroundDataDefault.honorGained)
        battlegroundDataCells['honorGained'] = cellText;
      end

      cellText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    end
  end
end

-- Table is initialized in BuildUI.

-- Update faction icon texture based on player faction.
local function UpdateFactionIcon()
  if not factionIcon then
    return
  end
  local factionName = UnitFactionGroup("player")
  if factionName == "Horde" then
    factionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
  elseif factionName == "Alliance" then
    factionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
  else
    factionIcon:SetTexture(nil) -- No faction texture.
  end
end

-- Toggle frame visibility depending on settings and instance type.
local function UpdateFrameVisibility()
  if not templateFrame then
    return
  end
  if BGWOWClassicStatisticShowDB.showOutsideBG then
    templateFrame:Show()
    return
  end
  local _, instanceType = IsInInstance()
  if instanceType == "pvp" then
    templateFrame:Show()
  else
    templateFrame:Hide()
  end
end

-- Apply current scale setting.
local function ApplyFrameScale()
  if not templateFrame then
    return
  end
  templateFrame:SetScale(BGWOWClassicStatisticShowDB.frameScale or DEFAULT_FRAME_SCALE)
end

-- Restore saved frame position (relative to UIParent).
local function ApplyFramePosition()
  if not templateFrame then
    return
  end
  local pos = BGWOWClassicStatisticShowDB.position
  if not pos then
    return
  end
  templateFrame:ClearAllPoints()
  templateFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end

-- Remember frame position after dragging.
local function SaveFramePosition(frame)
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  BGWOWClassicStatisticShowDB.position = {
    point = point,
    relativePoint = relativePoint,
    x = x,
    y = y
  }
end

local function HasOptionsAPI()
  return (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory)
    or InterfaceOptions_AddCategory
end

-- Create settings UI (TBC Settings API or legacy interface).
local function CreateOptionsPanel()
  if optionsPanelCreated or not HasOptionsAPI() then
    return
  end
  optionsPanelCreated = true
  local panel = CreateFrame("Frame", "BGWOWClassicStatisticShowOptions", UIParent)
  panel.name = ADDON_NAME

  panel:SetScript("OnShow", function(self)
    if self.initialized then
      return
    end
    self.initialized = true

    local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ADDON_NAME)

    local templateLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    templateLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    templateLabel:SetText("Frame template")

    local dropdown = CreateFrame("Frame", "BGWOWClassicStatisticShowTemplateDropdown", self, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", templateLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(dropdown, 200)
    UIDropDownMenu_Initialize(dropdown, function()
      for _, templateName in ipairs(frameTemplates) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = templateName
        info.value = templateName
        info.checked = (BGWOWClassicStatisticShowDB.frameTemplate == templateName)
        info.func = function()
          BGWOWClassicStatisticShowDB.frameTemplate = templateName
          UIDropDownMenu_SetText(dropdown, templateName)
          if BuildUI then
            BuildUI()
          end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetText(dropdown, BGWOWClassicStatisticShowDB.frameTemplate)

    local showOutside = CreateFrame("CheckButton", "BGWOWClassicStatisticShowShowOutsideBG", self, "InterfaceOptionsCheckButtonTemplate")
    showOutside:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, -12)
    local showOutsideText = _G[showOutside:GetName() .. "Text"]
    showOutsideText:SetText("Show outside Battlegrounds")
    showOutside:SetChecked(BGWOWClassicStatisticShowDB.showOutsideBG)
    showOutside:SetScript("OnClick", function(self)
      BGWOWClassicStatisticShowDB.showOutsideBG = self:GetChecked()
      UpdateFrameVisibility()
    end)

    local scaleSlider = CreateFrame("Slider", "BGWOWClassicStatisticShowScaleSlider", self, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", showOutside, "BOTTOMLEFT", 0, -24)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetValue(BGWOWClassicStatisticShowDB.frameScale or DEFAULT_FRAME_SCALE)
    _G[scaleSlider:GetName() .. "Text"]:SetText("Frame size")
    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
      local scaled = math.floor(value * 100 + 0.5) / 100
      BGWOWClassicStatisticShowDB.frameScale = scaled
      ApplyFrameScale()
    end)

  end)

  -- Register settings category in the appropriate UI system.
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME)
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

-- Register a list of events on a frame.
local function registerEvents(frame, events)
  for _, eventName in pairs(events) do
    frame:RegisterEvent(eventName)
  end
end

-- Attach a single OnEvent handler.
local function setEventListeners(frame, callback)
  frame:SetScript('OnEvent', callback)
end

local EVENTS = {
  'UPDATE_BATTLEFIELD_SCORE', -- Scoreboard data arrived
  'ZONE_CHANGED_NEW_AREA',
  'PLAYER_ENTERING_WORLD'
}

-- Main event handler for updating scores and visibility.
local function onEvent(self, event, ...)
  if event == 'PLAYER_ENTERING_WORLD' then
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" then
      StartScoreTicker()
    else
      StopScoreTicker()
    end
    UpdateFactionIcon()
  end
  UpdateFrameVisibility()

  if event ~= 'UPDATE_BATTLEFIELD_SCORE' then
    RequestBattlefieldScoreData()
  end

  getPlayerData();
end

-- Rebuild the UI when the template changes.
BuildUI = function()
  if templateFrame then
    templateFrame:UnregisterAllEvents()
    templateFrame:Hide()
  end

  templateFrame = CreateShadowOverlayFrame(
    "Frame",
    nil,
    UIParent,
    BGWOWClassicStatisticShowDB.frameTemplate
  )
  templateFrame:Hide()
  ApplyFramePosition()

  templateFrame:SetMovable(true)
  templateFrame:SetClampedToScreen(true)
  templateFrame:EnableMouse(true)
  templateFrame:RegisterForDrag("LeftButton")
  templateFrame:SetScript("OnDragStart", templateFrame.StartMoving)
  templateFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFramePosition(self)
  end)

  playerName = GetUnitName('player')
  local _, resolvedClass = UnitClass("player")
  playerClass = resolvedClass
  local classColor = RAID_CLASS_COLORS[playerClass]

  header = templateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  header:SetPoint("TOPLEFT", templateFrame, "TOPLEFT", 27, -14)
  if classColor then
    header:SetTextColor(classColor.r, classColor.g, classColor.b)
  end
  header:SetText(playerName)
  header:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")

  factionIcon = templateFrame:CreateTexture(nil, "OVERLAY")
  factionIcon:SetSize(30, 30)
  factionIcon:SetPoint("TOPRIGHT", templateFrame, "TOPRIGHT", 2, -11)

  classIcon = templateFrame:CreateTexture(nil, "OVERLAY")
  classIcon:SetSize(12, 12)
  classIcon:SetPoint("TOPLEFT", templateFrame, "TOPLEFT", 13, -13)
  classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
  if CLASS_ICON_TCOORDS and playerClass and CLASS_ICON_TCOORDS[playerClass] then
    classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[playerClass]))
  end

  -- Reset cell references before rebuilding table.
  battlegroundDataCells.killingBlows = nil
  battlegroundDataCells.honorableKills = nil
  battlegroundDataCells.deaths = nil
  battlegroundDataCells.honorGained = nil
  ApplyFrameScale()
  CreateTable(templateFrame)
  UpdateFactionIcon()
  UpdateFrameVisibility()
  getPlayerData()

  registerEvents(templateFrame, EVENTS)
  setEventListeners(templateFrame, onEvent)
end

-- Initialize after SavedVariables are loaded and player info is available.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addonName)
  if event == "PLAYER_LOGIN" then
    InitDB()
    BuildUI()
    CreateOptionsPanel()
    self:UnregisterEvent("PLAYER_LOGIN")
  elseif event == "ADDON_LOADED" and addonName == "Blizzard_InterfaceOptions" then
    -- Legacy clients may load the options UI on demand.
    if BGWOWClassicStatisticShowDB then
      CreateOptionsPanel()
    end
  end
end)
