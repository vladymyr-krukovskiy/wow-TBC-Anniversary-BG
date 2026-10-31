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
BGWOWClassicStatisticShowDB = BGWOWClassicStatisticShowDB or {
  frameTemplate = DEFAULT_FRAME_TEMPLATE,
  frameScale = DEFAULT_FRAME_SCALE,
  showOutsideBG = true
}
if not IsFrameTemplateValid(BGWOWClassicStatisticShowDB.frameTemplate) then
  BGWOWClassicStatisticShowDB.frameTemplate = DEFAULT_FRAME_TEMPLATE
end
if BGWOWClassicStatisticShowDB.frameScale == nil then
  BGWOWClassicStatisticShowDB.frameScale = DEFAULT_FRAME_SCALE
end
if BGWOWClassicStatisticShowDB.showOutsideBG == nil then
  BGWOWClassicStatisticShowDB.showOutsideBG = true
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
      cell.bg = cell:CreateTexture(nil, "BACKGROUND")
      cell.bg:SetAllPoints()
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

-- Create settings UI (TBC Settings API or legacy interface).
local function CreateOptionsPanel()
  if optionsPanelCreated then
    return
  end
  optionsPanelCreated = true
  local panel = CreateFrame("Frame", "BGWOWClassicStatisticShowOptions", UIParent)
  panel.name = "BGWOWClassicStatisticShow"

  panel:SetScript("OnShow", function(self)
    if self.initialized then
      return
    end
    self.initialized = true

    local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BGWOWClassicStatisticShow")

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
    local category = Settings.RegisterCanvasLayoutCategory(panel, "BGWOWClassicStatisticShow")
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end
 
-- Update faction icon on zone load.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", UpdateFactionIcon)

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
  'PVP_RATED_STATS_UPDATE',
  'UPDATE_BATTLEFIELD_SCORE',
  'PVP_WORLDSTATE_UPDATE',
  'ZONE_CHANGED_NEW_AREA',
  'ZONE_CHANGED',
  'PLAYER_ENTERING_WORLD',
  'UPDATE_BATTLEFIELD_STATUS',
  'PLAYER_LOGIN',
  'PLAYER_LOGOUT', -- Fired when about to log out
  'ADDON_LOADED'   -- Fired when saved variables are loaded
}

-- Main event handler for updating scores and visibility.
local function onEvent(self, event, unit, ...)
  if
      (event == 'PVP_RATED_STATS_UPDATE'
        or event == 'HONOR_LEVEL_UPDATE'
        or event == 'UPDATE_BATTLEFIELD_SCORE'
        or event == 'ZONE_CHANGED_NEW_AREA'
        or event == 'ZONE_CHANGED'
        or event == 'PLAYER_ENTERING_WORLD')
  then
    if event == 'PLAYER_ENTERING_WORLD' then
      local _, instanceType = IsInInstance()
      if instanceType == "pvp" then
        StartScoreTicker()
      else
        StopScoreTicker()
      end
    end
    UpdateFrameVisibility()

    if event ~= 'UPDATE_BATTLEFIELD_SCORE' then
      RequestBattlefieldScoreData()
    end

    getPlayerData();
  end
end

-- Rebuild the UI when the template changes.
BuildUI = function()
  local anchorPoint, relativeTo, relativePoint, xOfs, yOfs
  if templateFrame then
    anchorPoint, relativeTo, relativePoint, xOfs, yOfs = templateFrame:GetPoint(1)
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

  if anchorPoint then
    templateFrame:ClearAllPoints()
    templateFrame:SetPoint(anchorPoint, relativeTo or UIParent, relativePoint or anchorPoint, xOfs or 0, yOfs or 0)
  end

  templateFrame:SetMovable(true)
  templateFrame:EnableMouse(true)
  templateFrame:RegisterForDrag("LeftButton")
  templateFrame:SetScript("OnDragStart", templateFrame.StartMoving)
  templateFrame:SetScript("OnDragStop", templateFrame.StopMovingOrSizing)

  playerName = GetUnitName('player', showServerName)
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

  registerEvents(templateFrame, EVENTS)
  setEventListeners(templateFrame, onEvent)
end

-- Initialize UI and register settings.
BuildUI()
if Settings and Settings.RegisterAddOnCategory then
  CreateOptionsPanel()
elseif InterfaceOptions_AddCategory then
  CreateOptionsPanel()
else
  local optionsLoader = CreateFrame("Frame")
  optionsLoader:RegisterEvent("ADDON_LOADED")
  optionsLoader:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "Blizzard_InterfaceOptions" then
      CreateOptionsPanel()
      optionsLoader:UnregisterEvent("ADDON_LOADED")
    end
  end)
end
-- Fallback panel registration on login.
local fallbackOptions = CreateFrame("Frame")
fallbackOptions:RegisterEvent("PLAYER_LOGIN")
fallbackOptions:SetScript("OnEvent", function()
  CreateOptionsPanel()
  fallbackOptions:UnregisterEvent("PLAYER_LOGIN")
end)
