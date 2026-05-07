-- TeamManager: UI_Floating — floating team label and member list panel

-- Détecte si au moins un membre (hors leader) de la team affichée ne suit pas le leader.
-- Sert à déclencher l'alerte « perte de follow » sur le panel flottant.
local function _isFollowAlertActive(teamName)
  if not teamName then return false end
  local t = TM.db and TM.db.teams and TM.db.teams[teamName]
  if not t or not t.leader then return false end
  local leaderShort = t.leader:match("^(.-)%-") or t.leader
  local cache = TM.memberStateCache or {}
  for _, name in ipairs(t.members or {}) do
    local short = name:match("^(.-)%-") or name
    if short ~= leaderShort then
      local state = cache[short]
      if not state or state.follow ~= leaderShort then
        return true
      end
    end
  end
  return false
end

-- Crée (ou récupère) la texture rouge translucide superposée à un frame
local function _ensureAlertOverlay(frame)
  if frame.alertOverlay then return frame.alertOverlay end
  local tex = frame:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(frame)
  tex:SetColorTexture(1, 0, 0, 0.5)
  tex:Hide()
  frame.alertOverlay = tex
  return tex
end

-- OnUpdate: fait clignoter l'overlay rouge tant que l'alerte est active,
-- et le masque dès que tous les membres suivent le leader.
local _alertAccum = 0
local function _floatingAlertOnUpdate(self, elapsed)
  _alertAccum = _alertAccum + (elapsed or 0)
  if _alertAccum < 0.05 then return end
  _alertAccum = 0

  local active = _isFollowAlertActive(self.teamName)
  local flOverlay = self.alertOverlay
  local panel = TM.ui and TM.ui.floatingMemberList
  local panelOverlay = panel and panel.alertOverlay

  -- Option de configuration : si désactivée, on s'assure que les overlays sont masqués
  if TM.db and TM.db.followAlert == false then
    if flOverlay and flOverlay:IsShown() then flOverlay:Hide() end
    if panelOverlay and panelOverlay:IsShown() then panelOverlay:Hide() end
    return
  end

  if not active then
    if flOverlay and flOverlay:IsShown() then flOverlay:Hide() end
    if panelOverlay and panelOverlay:IsShown() then panelOverlay:Hide() end
    return
  end

  -- Pulsation d'alpha entre 0.15 et 0.55 (clignotement doux)
  local pulse = (math.sin(GetTime() * 5) + 1) * 0.5  -- 0..1
  local alpha = 0.15 + pulse * 0.4

  if flOverlay then
    flOverlay:SetAlpha(alpha)
    if not flOverlay:IsShown() then flOverlay:Show() end
  end
  if panelOverlay and panel and panel:IsShown() then
    panelOverlay:SetAlpha(alpha)
    if not panelOverlay:IsShown() then panelOverlay:Show() end
  elseif panelOverlay and panelOverlay:IsShown() then
    panelOverlay:Hide()
  end
end

local function SaveFloatingLabelPos()
  local fl = TM.ui.floatingLabel
  if not fl then return end
  local point, _, relPoint, x, y = fl:GetPoint()
  local expanded = (TM.ui.floatingMemberList and TM.ui.floatingMemberList:IsShown()) and true or false
  local pcd = TM.GetPerCharDB()
  pcd.floatingLabel = { point = point, relPoint = relPoint, x = x, y = y,
                        teamName = fl.teamName, expanded = expanded }
end

function TM.DestroyFloatingTeamLabel()
  local ui = TM.ui
  if ui.floatingMemberList then ui.floatingMemberList:Hide(); ui.floatingMemberList = nil end
  if ui.floatingLabel      then ui.floatingLabel:Hide();      ui.floatingLabel = nil      end
  local pcd = TM.GetPerCharDB()
  pcd.floatingLabel = nil
  TM.DebugPrint("Floating team label détruit")
end

function TM.CreateFloatingTeamLabel(teamName, point, relPoint, x, y)
  if not teamName or teamName == "" then return end
  local ui = TM.ui
  if ui.floatingLabel then
    ui.floatingLabel.teamName = teamName
    ui.floatingLabel.text:SetText(teamName)
    SaveFloatingLabelPos()
    ui.floatingLabel:Show()
    return
  end

  local fl = CreateFrame("Frame", "TeamManagerFloatingLabel", UIParent, "BackdropTemplate")
  fl:SetSize(140, 28)
  fl:SetFrameStrata("MEDIUM")
  fl:SetClampedToScreen(true)
  fl:SetMovable(true)
  fl:EnableMouse(true)
  fl:RegisterForDrag("LeftButton")
  fl:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  fl:SetBackdropColor(0, 0, 0, 0.8)
  fl:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

  fl.text = fl:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fl.text:SetPoint("CENTER")
  fl.text:SetText(teamName)
  fl.teamName = teamName

  fl:SetScript("OnDragStart", function(self) self:StartMoving() end)
  fl:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing(); SaveFloatingLabelPos() end)

  fl:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      if IsShiftKeyDown() then TEAMMANAGER_TOGGLEUI()
      else TM.InviteTeam(self.teamName) end
    elseif button == "RightButton" then
      if IsShiftKeyDown() then TM.DestroyFloatingTeamLabel()
      else TM.ToggleFloatingMemberList() end
    end
  end)

  fl:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Team: " .. (self.teamName or ""))
    GameTooltip:AddLine("Clic gauche: inviter la team",          0.5, 1,   0.5)
    GameTooltip:AddLine("Shift+Clic gauche: ouvrir la config",   0.5, 0.8, 1)
    GameTooltip:AddLine("Clic droit: afficher/masquer membres",  1,   1,   1)
    GameTooltip:AddLine("Shift+Clic droit pour supprimer",       1,   0.5, 0.5)
    GameTooltip:AddLine("Glisser pour déplacer",                 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  fl:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if point and x and y then
    fl:SetPoint(point, UIParent, relPoint or point, x, y)
  else
    fl:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  end

  fl.text:SetWidth(0)
  local textW = fl.text:GetStringWidth() or 80
  fl:SetWidth(math.max(60, textW + 24))

  TM.SkinFloatingLabel(fl)
  _ensureAlertOverlay(fl)
  fl:SetScript("OnUpdate", _floatingAlertOnUpdate)
  ui.floatingLabel = fl
  SaveFloatingLabelPos()
  TM.DebugPrint("Floating team label créé pour:", teamName)
end

function TM.UpdateFloatingTeamLabel(teamName)
  local ui = TM.ui
  if not ui.floatingLabel then return end
  if not teamName or teamName == "" then return end
  ui.floatingLabel.teamName = teamName
  ui.floatingLabel.text:SetText(teamName)
  ui.floatingLabel.text:SetWidth(0)
  local textW = ui.floatingLabel.text:GetStringWidth() or 80
  ui.floatingLabel:SetWidth(math.max(60, textW + 24))
  SaveFloatingLabelPos()
  if ui.floatingMemberList and ui.floatingMemberList:IsShown() then
    TM.RefreshFloatingMemberList()
  end
end

function TM.RefreshFloatingMemberList()
  local ui = TM.ui
  local fl = ui.floatingLabel
  if not fl then return end
  local teamName = fl.teamName
  if not teamName or not TM.db.teams[teamName] then return end
  local t = TM.db.teams[teamName]
  local members = t.members or {}

  local panel = ui.floatingMemberList
  if not panel then
    panel = CreateFrame("Frame", nil, fl, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", fl, "BOTTOMLEFT", 0, -2)
    panel:SetFrameStrata("MEDIUM")
    panel:SetBackdrop({
      bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.85)
    panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    panel.rows = {}
    TM.SkinFloatingLabel(panel)
    _ensureAlertOverlay(panel)
    ui.floatingMemberList = panel
  end

  local leaderShort = t.leader and (t.leader:match("^(.-)%-") or t.leader) or nil
  local maxWidth = fl:GetWidth()
  local rowHeight = 16
  local count = #members

  for i = 1, math.max(count, #panel.rows) do
    if not panel.rows[i] then
      local row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row:SetJustifyH("LEFT")
      row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6 - (i - 1) * rowHeight)
      panel.rows[i] = row
    end
    local row = panel.rows[i]
    if i <= count then
      local name   = members[i]
      local short  = name:match("^(.-)%-") or name
      local isLeader = (leaderShort and short == leaderShort)
      local online = TM.IsMemberOnline(name)
      local display = name
      if isLeader then display = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:0|t " .. name end

      -- État follow/assist à gauche du nom (si option activée)
      local statePrefix = ""
      if TM.db and TM.db.showStateDisplay ~= false then
        local state = TM.memberStateCache and TM.memberStateCache[short]
        if state then
          local f = state.follow
          local a = state.assist
          if f and a then
            if f == a then
              statePrefix = "|cffFF4444[" .. f .. "]|r  "
            else
              statePrefix = "|cff44FF44[" .. a .. "]|r  "
            end
          elseif a then
            statePrefix = "|cff44FF44[" .. a .. "]|r  "
          elseif f then
            statePrefix = "|cffFFFF00[" .. f .. "]|r  "
          end
        end
      end
      display = statePrefix .. display

      local cached = TM.memberXPCache[short]
      local lvl, xpPct, classFile, raceFile, faction, specName, sex
      if cached then
        lvl = cached.level; xpPct = cached.xpPct; classFile = cached.classFile
        raceFile = cached.raceFile; faction = cached.faction; specName = cached.specName; sex = cached.sex
      end
      local unit = TM.FindUnitByName(short)
      if unit then
        if not lvl      or lvl      == 0  then lvl      = UnitLevel(unit)         end
        if not classFile or classFile == "" then _, classFile = UnitClass(unit)    end
        if not raceFile  or raceFile  == "" then _, raceFile  = UnitRace(unit)     end
        if not faction   or faction   == "" then faction   = UnitFactionGroup(unit) end
        if not sex then sex = UnitSex(unit) end
      end
      if lvl and lvl > 0 then
        display = display .. (xpPct
          and string.format("  |cffaaaaaa(Lv%d - %.1f%%)|r", lvl, xpPct)
          or  string.format("  |cffaaaaaa(Lv%d)|r", lvl))
      end
      if faction and faction ~= "" then
        local fIcon = (faction == "Alliance") and "Interface\\PVPFrame\\PVP-Currency-Alliance"
          or (faction == "Horde") and "Interface\\PVPFrame\\PVP-Currency-Horde" or nil
        if fIcon then display = display .. " |T" .. fIcon .. ":0|t" end
      end
      if raceFile and raceFile ~= "" then
        local sexStr  = (sex == 3) and "female" or "male"
        local raceKey = TM.RACE_ATLAS_REMAP[raceFile] or raceFile:lower()
        display = display .. " |A:raceicon-" .. raceKey .. "-" .. sexStr .. ":14:14|a"
      end
      if classFile and classFile ~= "" then
        display = display .. " |A:classicon-" .. classFile:lower() .. ":14:14|a"
      end
      if specName and specName ~= "" then
        display = display .. " |cffcccccc" .. specName .. "|r"
      end

      row:SetText(display)
      row:SetTextColor(online and 0 or 1, online and 1 or 0, 0)
      row:Show()
      row:SetWidth(0)
      local rw = (row:GetStringWidth() or 60) + 16
      if rw > maxWidth then maxWidth = rw end

      -- click overlay
      if not panel.clickBtns then panel.clickBtns = {} end
      if not panel.clickBtns[i] then
        local cb = CreateFrame("Button", nil, panel)
        cb:RegisterForClicks("LeftButtonUp")
        cb:SetScript("OnClick", function(self) TM.InspectMember(self.memberName) end)
        cb:SetScript("OnEnter", function(self)
          if not self.memberName then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText(self.memberName, 1, 1, 1)
          GameTooltip:AddLine("Clic gauche : Inspecter", 0.5, 1, 0.5)
          GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        panel.clickBtns[i] = cb
      end
      local cb = panel.clickBtns[i]
      cb.memberName = members[i]
      cb:SetPoint("TOPLEFT",    panel, "TOPLEFT",    8,  -6 - (i - 1) * rowHeight)
      cb:SetPoint("TOPRIGHT",   panel, "TOPRIGHT",  -8,  -6 - (i - 1) * rowHeight)
      cb:SetHeight(rowHeight)
      cb:Show()
    else
      row:SetText(""); row:Hide()
      if panel.clickBtns and panel.clickBtns[i] then panel.clickBtns[i]:Hide() end
    end
  end

  local panelHeight = math.max(24, count * rowHeight + 12)
  panel:SetSize(math.max(fl:GetWidth(), maxWidth), panelHeight)
end

function TM.ToggleFloatingMemberList()
  local ui = TM.ui
  local fl = ui.floatingLabel
  if not fl then return end
  if ui.floatingMemberList and ui.floatingMemberList:IsShown() then
    ui.floatingMemberList:Hide()
  else
    TM.RefreshFloatingMemberList()
    if ui.floatingMemberList then ui.floatingMemberList:Show() end
  end
  SaveFloatingLabelPos()
end
