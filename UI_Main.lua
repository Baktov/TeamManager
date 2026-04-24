-- TeamManager: UI_Main — main window (BuildUI, SelectTeam, RefreshTeamList, ToggleUI)

function TM.SelectTeam(name, save)
  TM.selectedTeam = name
  TM.DebugPrint("SelectTeam called:", tostring(name), "save=", tostring(save))
  if name and save ~= false then TM.SaveSelectedTeamForCharacter(name) end
  if name and TM.UpdateFloatingTeamLabel then TM.UpdateFloatingTeamLabel(name) end
  if TM.UpdateAssistButton then TM.UpdateAssistButton() end
  if not name then return end
  local t = TM.db.teams[name]
  if not t then return end

  TM.DebugPrint("SelectTeam debug - raw members count (#):", #t.members or 0)
  for k, v in pairs(t.members) do TM.DebugPrint(" member key:", k, "value:", v) end

  local ui = TM.ui
  ui.teamName:SetText(name)
  ui.leader:SetText(t.leader or "(aucun)")

  -- enable Invite only if current player is the team leader
  do
    local allowInvite = false
    if t.leader and t.leader ~= "" then
      local leaderShort = t.leader:match("^(.-)%-") or t.leader
      if leaderShort == UnitName("player") then allowInvite = true end
    end
    if ui.inviteBtn then
      if allowInvite then ui.inviteBtn:Enable() else ui.inviteBtn:Disable() end
    end
  end

  -- populate member rows
  ui.selectedMember = nil
  if ui.memberRows then
    local membersList = TM.CompactMembersArray(t.members)
    TM.DebugPrint("SelectTeam debug - compacted members count:", #membersList)
    for i, v in ipairs(membersList) do TM.DebugPrint(" compact["..i.."]=", v) end

    for i, row in ipairs(ui.memberRows) do
      local ok, err = pcall(function()
        local memberName = membersList[i]
        if memberName then
          local online    = TM.IsMemberOnline(memberName)
          local short     = memberName:match("^(.-)%-") or memberName
          local cached    = TM.memberXPCache[short]
          local lvl       = cached and cached.level
          local xpPct     = cached and cached.xpPct
          local classFile = cached and cached.classFile
          local raceFile  = cached and cached.raceFile
          local faction   = cached and cached.faction
          local specName  = cached and cached.specName
          local sex       = cached and cached.sex
          local unit      = TM.FindUnitByName(short)
          if unit then
            if not lvl       or lvl       == 0  then lvl       = UnitLevel(unit)          end
            if not classFile or classFile  == "" then _, classFile = UnitClass(unit)        end
            if not raceFile  or raceFile   == "" then _, raceFile  = UnitRace(unit)         end
            if not faction   or faction    == "" then faction    = UnitFactionGroup(unit)   end
            if not sex then sex = UnitSex(unit) end
          end
          local display = memberName
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
          row.nameLabel:SetText(display)
          row.nameLabel:SetTextColor(online and 0 or 1, online and 1 or 0, 0)
          row.nameLabel.memberName = memberName
          row.nameLabel:Show()
          if row.nameLabel._clickBtn then row.nameLabel._clickBtn:Show() end
          TM.DebugPrint("SelectTeam row set -", i, "name=", memberName, "online=", tostring(online))
        else
          row.nameLabel.memberName = nil
          row.nameLabel:Hide()
          if row.nameLabel._clickBtn then row.nameLabel._clickBtn:Hide() end
        end
      end)
      if not ok then TM.DebugPrint("SelectTeam row error on index", i, "-", tostring(err)) end
    end
  end

  -- highlight selected team in the left list
  if ui.listButtons then
    for _, b in ipairs(ui.listButtons) do
      if b.teamName == name then b:LockHighlight() else b:UnlockHighlight() end
    end
  end
end

function TM.RefreshTeamList()
  local ui = TM.ui
  local count = 0
  if TM.db and TM.db.teams then for _ in pairs(TM.db.teams) do count = count + 1 end end
  TM.DebugPrint("RefreshTeamList: équipes détectées:", count)
  local i = 1
  for name, _ in pairs(TM.db.teams) do
    TM.DebugPrint(" placing team", i, name)
    if ui.listButtons[i] then
      ui.listButtons[i]:SetText(name)
      ui.listButtons[i]:Show()
      ui.listButtons[i].teamName = name
      i = i + 1
    end
  end
  for j = i, #ui.listButtons do ui.listButtons[j]:Hide() end
end

function TM.BuildUI()
  local ui = TM.ui
  if ui.frame then return end

  local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
  local width  = math.min(math.max(600, math.floor(screenW * 0.6)), screenW - 120)
  local height = math.min(math.max(340, math.floor(screenH * 0.6)), screenH - 120)

  local pcd   = TM.GetPerCharDB()
  local saved = pcd.framePos or TM.db.framePos
  if saved and saved.width and saved.height then
    width  = math.max(600, math.min(saved.width,  screenW - 20))
    height = math.max(340, math.min(saved.height, screenH - 20))
  end

  local f = CreateFrame("Frame", "TeamManagerUI", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(width, height)
  if saved and saved.point and saved.x and saved.y then
    f:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x, saved.y)
  else
    f:SetPoint("CENTER")
  end
  f:Hide()
  ui.frame = f

  -- ── Left: team list ───────────────────────────────────────────────────────
  local listBG = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
  ui.listBG = listBG
  listBG:SetPoint("TOPLEFT", 12, -30)
  local listWidth       = math.max(160, math.floor(width * 0.28))
  local listInnerHeight  = height - 60
  -- sideWidth: chaque moitié du panneau droit (membersFrame / optionsBG)
  -- marge gauche 12 + listWidth + gap 20 + 2*side + gap 8 + marge droite 12 = width
  local sideWidth = math.floor((width - listWidth - 52) / 2)
  listBG:SetSize(listWidth, listInnerHeight)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -6)
  title:SetText("Teams")

  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:SetResizable(true)
  f:SetResizeBounds(600, 340, screenW - 20, screenH - 20)

  local header = CreateFrame("Frame", nil, f)
  header:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -4)
  header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -4)
  header:SetHeight(28)
  header:EnableMouse(true)
  header:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then f:StartMoving() end
  end)
  header:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

  ui.listButtons = {}
  for i = 1, 12 do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(listWidth - 20, 22)
    b:SetPoint("TOPLEFT", listBG, "TOPLEFT", 8, -8 - (i - 1) * 24)
    b:SetText("")
    b:SetScript("OnClick", function(self)
      if self.teamName then TM.SelectTeam(self.teamName) end
    end)
    ui.listButtons[i] = b
  end

  -- ── Right: team details ───────────────────────────────────────────────────
  local rightWidth = width - listWidth - 44

  ui.teamName = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  ui.teamName:SetHeight(24)
  ui.teamName:SetPoint("TOPLEFT",  listBG, "TOPRIGHT",  20, 0)
  ui.teamName:SetPoint("TOPRIGHT", f,      "TOPRIGHT", -12, 0)
  ui.teamName:SetAutoFocus(false)
  ui.teamName:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ui.teamName:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Nom d'\195\169quipe", 1, 1, 1)
    GameTooltip:AddLine("Saisissez un nom puis cliquez sur Create", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Glissez l'ic\195\180ne \195\160 gauche pour \195\169pingler l'\195\169quipe \195\160 l'\195\169cran", 0.6, 0.9, 1)
    GameTooltip:Show()
  end)
  ui.teamName:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local dragHandle = CreateFrame("Button", nil, f)
  dragHandle:SetSize(20, 20)
  dragHandle:SetPoint("RIGHT", ui.teamName, "LEFT", -2, 0)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle.icon = dragHandle:CreateTexture(nil, "ARTWORK")
  dragHandle.icon:SetAllPoints()
  dragHandle.icon:SetTexture("Interface\\CURSOR\\UI-Cursor-Move")
  dragHandle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Glisser pour épingler le nom de la team")
    GameTooltip:Show()
    self.icon:SetVertexColor(1, 1, 0)
  end)
  dragHandle:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    self.icon:SetVertexColor(1, 1, 1)
  end)
  dragHandle:SetScript("OnDragStart", function(self)
    if not ui.dragProxy then
      local dp = CreateFrame("Frame", nil, UIParent)
      dp:SetSize(120, 24)
      dp:SetFrameStrata("TOOLTIP")
      dp.text = dp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      dp.text:SetPoint("CENTER")
      dp.bg = dp:CreateTexture(nil, "BACKGROUND")
      dp.bg:SetAllPoints()
      dp.bg:SetColorTexture(0, 0, 0, 0.7)
      ui.dragProxy = dp
    end
    local name = TM.selectedTeam or ui.teamName:GetText()
    ui.dragProxy.text:SetText(name or "")
    ui.dragProxy.text:SetWidth(0)
    local tw = (ui.dragProxy.text:GetStringWidth() or 60) + 16
    ui.dragProxy:SetWidth(math.max(60, tw))
    ui.dragProxy:Show()
    ui.dragProxy:SetScript("OnUpdate", function(self)
      local scale = UIParent:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      self:ClearAllPoints()
      self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    end)
  end)
  dragHandle:SetScript("OnDragStop", function(self)
    if ui.dragProxy then ui.dragProxy:Hide(); ui.dragProxy:SetScript("OnUpdate", nil) end
    local name = TM.selectedTeam or ui.teamName:GetText()
    if name and name ~= "" then
      local scale = UIParent:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      local px = cx / scale - UIParent:GetWidth()  / 2
      local py = cy / scale - UIParent:GetHeight() / 2
      TM.CreateFloatingTeamLabel(name, "CENTER", "CENTER", px, py)
    end
  end)
  ui.dragHandle = dragHandle

  -- Invite button
  local inviteBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  inviteBtn:SetPoint("TOPLEFT", ui.teamName, "BOTTOMLEFT", 0, -6)
  inviteBtn:SetSize(100, 22)
  inviteBtn:SetText("Invite")
  inviteBtn:SetScript("OnClick", function()
    if not TM.selectedTeam then TM.Print("Aucune équipe sélectionnée"); return end
    TM.InviteTeam(TM.selectedTeam)
  end)
  ui.inviteBtn = inviteBtn

  -- Create button
  local createBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ui.createBtn = createBtn
  createBtn:SetPoint("LEFT", inviteBtn, "RIGHT", 6, 0)
  createBtn:SetSize(100, 22)
  createBtn:SetText("Create")
  createBtn:SetScript("OnClick", function()
    local name = ui.teamName:GetText()
    TM.CreateTeam(name)
    TM.RefreshTeamList()
    TM.SelectTeam(name)
    ui.teamName:ClearFocus()
  end)

  -- Delete button
  local delBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ui.delBtn = delBtn
  delBtn:SetPoint("LEFT", createBtn, "RIGHT", 6, 0)
  delBtn:SetSize(100, 22)
  delBtn:SetText("Delete")
  delBtn:SetScript("OnClick", function()
    local name = ui.teamName:GetText()
    TM.DeleteTeam(name)
    TM.RefreshTeamList()
    TM.SelectTeam(nil)
    ui.teamName:ClearFocus()
  end)

  -- Leader labels
  local leaderLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  leaderLabel:SetPoint("TOPLEFT", inviteBtn, "BOTTOMLEFT", 0, -10)
  leaderLabel:SetText("Leader:")
  ui.leader = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ui.leader:SetPoint("LEFT", leaderLabel, "RIGHT", 6, 0)

  -- Members area
  local membersLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  membersLabel:SetPoint("TOPLEFT", leaderLabel, "BOTTOMLEFT", 0, -10)
  membersLabel:SetText("Members:")
  local membersHeight = math.max(80, listInnerHeight - 140)
  local membersFrame = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
  membersFrame:SetPoint("TOPLEFT", membersLabel, "BOTTOMLEFT", 0, -6)
  membersFrame:SetSize(sideWidth, membersHeight)
  ui.membersFrame = membersFrame
  ui.memberRows   = {}

  for i = 1, 16 do
    local y = -6 - (i - 1) * 22
    local nameLabel = membersFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", membersFrame, "TOPLEFT", 8, y)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetSize(membersFrame:GetWidth() - 16, 20)
    nameLabel:SetText("")
    nameLabel:Hide()
    nameLabel.memberName = nil

    local clickBtn = CreateFrame("Button", nil, membersFrame)
    clickBtn:SetPoint("TOPLEFT",     nameLabel, "TOPLEFT",     -2,  2)
    clickBtn:SetPoint("BOTTOMRIGHT", nameLabel, "BOTTOMRIGHT",  2, -2)
    clickBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    clickBtn:SetScript("OnClick", function(self, button)
      local who = nameLabel.memberName
      if not who then return end
      if button == "LeftButton" and IsAltKeyDown() then
        if not TM.selectedTeam then TM.Print("Aucune \195\169quipe s\195\169lectionn\195\169e"); return end
        TM.SetLeader(TM.selectedTeam, who)
        TM.SelectTeam(TM.selectedTeam)
      elseif button == "RightButton" and IsAltKeyDown() then
        if not TM.selectedTeam then TM.Print("Aucune \195\169quipe s\195\169lectionn\195\169e"); return end
        TM.RemoveMember(TM.selectedTeam, who)
        TM.SelectTeam(TM.selectedTeam)
      elseif button == "LeftButton" then
        ui.selectedMember = who
        for _, row in ipairs(ui.memberRows) do
          if row.nameLabel.memberName == who then
            row.nameLabel:SetTextColor(1, 1, 0)
          else
            local nm = row.nameLabel.memberName
            if nm and TM.IsMemberOnline(nm) then row.nameLabel:SetTextColor(0, 1, 0)
            else row.nameLabel:SetTextColor(1, 0, 0) end
          end
        end
        TM.InspectMember(who)
      end
    end)
    clickBtn:SetScript("OnEnter", function(self)
      local who = nameLabel.memberName
      if not who then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(who, 1, 1, 1)
      GameTooltip:AddLine("Clic gauche : Inspecter", 0.5, 1, 0.5)
      GameTooltip:AddLine("Alt+Clic gauche : Promouvoir leader", 1, 0.85, 0)
      GameTooltip:AddLine("Alt+Clic droit : Supprimer de l'\195\169quipe", 1, 0.4, 0.4)
      GameTooltip:Show()
    end)
    clickBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    nameLabel._clickBtn = clickBtn

    ui.memberRows[i] = { nameLabel = nameLabel }
  end

  TM.DebugPrint("BuildUI debug - membersFrame width:", membersFrame:GetWidth())

  -- ── Options panel ──────────────────────────────────────────────────────────
  local optionsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  optionsLabel:SetPoint("BOTTOMLEFT", membersFrame, "TOPRIGHT", 8, 6)
  optionsLabel:SetText("Options:")

  local optionsBG = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
  ui.optionsBG = optionsBG
  optionsBG:SetPoint("TOPLEFT", optionsLabel, "BOTTOMLEFT", 0, -6)
  optionsBG:SetSize(sideWidth, membersHeight)

  -- Debug toggle (dans le panel Options)
  local debugLabel = optionsBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  debugLabel:SetPoint("TOPLEFT", optionsBG, "TOPLEFT", 8, -8)
  debugLabel:SetText("Debug")

  local debugToggle = CreateFrame("CheckButton", nil, optionsBG, "UICheckButtonTemplate")
  debugToggle:SetPoint("LEFT", debugLabel, "RIGHT", 6, 0)
  debugToggle:SetSize(24, 24)
  debugToggle:SetScript("OnClick", function(self)
    TM.debugEnabled = self:GetChecked()
    TM.db.debug = TM.debugEnabled
    if TM.debugEnabled then TM.Print("Debug activ\195\169") else TM.Print("Debug d\195\169sactiv\195\169") end
  end)
  debugToggle:SetChecked(TM.debugEnabled)
  ui.debugToggle = debugToggle

  -- Préfixe sync (dans le panel Options, sous le debug)
  local prefixLabel = optionsBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  prefixLabel:SetPoint("TOPLEFT", debugLabel, "BOTTOMLEFT", 0, -14)
  prefixLabel:SetText("Pr\195\169fixe sync:")

  local prefixInput = CreateFrame("EditBox", nil, optionsBG, "InputBoxTemplate")
  prefixInput:SetHeight(20)
  prefixInput:SetPoint("LEFT", prefixLabel, "RIGHT", 6, 0)
  prefixInput:SetPoint("RIGHT", optionsBG, "RIGHT", -8, 0)
  prefixInput:SetAutoFocus(false)
  prefixInput:SetMaxLetters(16)
  prefixInput:SetText((TM.db and TM.db.syncPrefix and TM.db.syncPrefix ~= "") and TM.db.syncPrefix or TM.SYNC_PREFIX)
  prefixInput:SetScript("OnEscapePressed", function(self)
    self:SetText(TM.SYNC_PREFIX)
    self:ClearFocus()
  end)
  local function applyPrefix(self)
    local newPrefix = self:GetText():match("^%s*(.-)%s*$")
    if newPrefix and newPrefix ~= "" then
      TM.SetSyncPrefix(newPrefix)
      TM.Print("Pr\195\169fixe sync mis \195\160 jour: " .. TM.SYNC_PREFIX)
    else
      self:SetText(TM.SYNC_PREFIX)
    end
    self:ClearFocus()
  end
  prefixInput:SetScript("OnEnterPressed", applyPrefix)
  prefixInput:SetScript("OnEditFocusLost", applyPrefix)
  prefixInput:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Pr\195\169fixe de communication addon")
    GameTooltip:AddLine("Les membres doivent utiliser le m\195\170me pr\195\169fixe", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Entr\195\169e pour valider, \195\137chap pour annuler", 0.5, 1, 0.5)
    GameTooltip:Show()
  end)
  prefixInput:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ui.prefixInput = prefixInput

  -- Option : affichage état follow/assist dans la fenêtre flottante
  local stateLabel = optionsBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  stateLabel:SetPoint("TOPLEFT", prefixLabel, "BOTTOMLEFT", 0, -14)
  stateLabel:SetText("Affichage état follow/assist")

  local stateToggle = CreateFrame("CheckButton", nil, optionsBG, "UICheckButtonTemplate")
  stateToggle:SetPoint("LEFT", stateLabel, "RIGHT", 6, 0)
  stateToggle:SetSize(24, 24)
  stateToggle:SetScript("OnClick", function(self)
    TM.db.showStateDisplay = self:GetChecked()
    local ui2 = TM.ui
    if ui2 and ui2.floatingMemberList and ui2.floatingMemberList:IsShown() then
      TM.RefreshFloatingMemberList()
    end
  end)
  stateToggle:SetChecked(TM.db.showStateDisplay ~= false)
  stateToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Affichage état follow/assist")
    GameTooltip:AddLine("Affiche à gauche du nom le joueur suivi/assisté", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffFFFF00Jaune|r: follow  |cff44FF44Vert|r: assist  |cffFF4444Rouge|r: les deux identiques", 1, 1, 1)
    GameTooltip:Show()
  end)
  stateToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ui.stateToggle = stateToggle

  -- Option : accepter les quêtes automatiquement
  local questLabel = optionsBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  questLabel:SetPoint("TOPLEFT", stateLabel, "BOTTOMLEFT", 0, -24)
  questLabel:SetText("Accepter les qu\195\170tes auto")

  local questToggle = CreateFrame("CheckButton", nil, optionsBG, "UICheckButtonTemplate")
  questToggle:SetPoint("LEFT", questLabel, "RIGHT", 6, 0)
  questToggle:SetSize(24, 24)
  questToggle:SetScript("OnClick", function(self)
    TM.db.autoAcceptQuest = self:GetChecked()
  end)
  questToggle:SetChecked(TM.db.autoAcceptQuest ~= false)
  questToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Accepter les qu\195\170tes automatiquement")
    GameTooltip:AddLine("Si le leader accepte une qu\195\170te, les membres qui ont", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("le m\195\170me PNJ cibl\195\169 acceptent automatiquement.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  questToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ui.questToggle = questToggle

  -- Option : sélection de dialogue PNJ automatique
  local gossipLabel = optionsBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  gossipLabel:SetPoint("TOPLEFT", questLabel, "BOTTOMLEFT", 0, -24)
  gossipLabel:SetText("S\195\169lection dialogue PNJ auto")

  local gossipToggle = CreateFrame("CheckButton", nil, optionsBG, "UICheckButtonTemplate")
  gossipToggle:SetPoint("LEFT", gossipLabel, "RIGHT", 6, 0)
  gossipToggle:SetSize(24, 24)
  gossipToggle:SetScript("OnClick", function(self)
    TM.db.autoSelectGossip = self:GetChecked()
  end)
  gossipToggle:SetChecked(TM.db.autoSelectGossip ~= false)
  gossipToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("S\195\169lection dialogue PNJ automatique")
    GameTooltip:AddLine("Si le leader clique sur une option de dialogue,", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("les membres qui ont la m\195\170me bulle PNJ ouverte", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("s\195\169lectionnent la m\195\170me option automatiquement.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  gossipToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ui.gossipToggle = gossipToggle

  -- Option : passer les cinématiques automatiquement
  local cinematicLabel = optionsBG:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cinematicLabel:SetPoint("TOPLEFT", gossipLabel, "BOTTOMLEFT", 0, -24)
  cinematicLabel:SetText("Passer les cin\195\169matiques auto")

  local cinematicToggle = CreateFrame("CheckButton", nil, optionsBG, "UICheckButtonTemplate")
  cinematicToggle:SetPoint("LEFT", cinematicLabel, "RIGHT", 6, 0)
  cinematicToggle:SetSize(24, 24)
  cinematicToggle:SetScript("OnClick", function(self)
    TM.db.autoSkipCinematic = self:GetChecked()
  end)
  cinematicToggle:SetChecked(TM.db.autoSkipCinematic ~= false)
  cinematicToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Passer les cin\195\169matiques automatiquement")
    GameTooltip:AddLine("Si le leader passe (\195\137chap) une cin\195\169matique,", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("les membres qui regardent la m\195\170me cin\195\169matique", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("la passent automatiquement.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  cinematicToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ui.cinematicToggle = cinematicToggle

  -- Member input row
  local inputWidth = math.max(140, rightWidth - 220)
  ui.memberInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  ui.memberInput:SetSize(inputWidth, 20)
  ui.memberInput:SetPoint("TOPLEFT", ui.membersFrame, "BOTTOMLEFT", 0, -8)
  ui.memberInput:SetAutoFocus(false)
  ui.memberInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ui.memberInput:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Ajouter un membre", 1, 1, 1)
    GameTooltip:AddLine("Saisissez Nom ou Nom-Royaume puis cliquez sur Add", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Utilisez Add Me, Add Target ou Add Group pour ajouter rapidement", 0.6, 0.9, 1)
    GameTooltip:Show()
  end)
  ui.memberInput:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ui.addBtn = addBtn
  addBtn:SetPoint("LEFT", ui.memberInput, "RIGHT", 6, 0)
  addBtn:SetSize(80, 22)
  addBtn:SetText("Add")
  addBtn:SetScript("OnClick", function()
    if not TM.selectedTeam then TM.Print("Aucune équipe sélectionnée"); return end
    local who = ui.memberInput:GetText()
    if who and who ~= "" then TM.AddMember(TM.selectedTeam, who); TM.SelectTeam(TM.selectedTeam) end
    ui.memberInput:ClearFocus()
  end)

  local addMeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ui.addMeBtn = addMeBtn
  addMeBtn:SetPoint("TOPLEFT", ui.memberInput, "BOTTOMLEFT", 0, -6)
  addMeBtn:SetSize(100, 22)
  addMeBtn:SetText("Add Me")
  addMeBtn:SetScript("OnClick", function()
    if not TM.selectedTeam then TM.Print("Aucune équipe sélectionnée"); return end
    TM.AddMe(TM.selectedTeam); TM.SelectTeam(TM.selectedTeam)
    ui.memberInput:ClearFocus()
  end)

  local addTargetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ui.addTargetBtn = addTargetBtn
  addTargetBtn:SetPoint("LEFT", addMeBtn, "RIGHT", 6, 0)
  addTargetBtn:SetSize(100, 22)
  addTargetBtn:SetText("Add Target")
  addTargetBtn:SetScript("OnClick", function()
    if not TM.selectedTeam then TM.Print("Aucune équipe sélectionnée"); return end
    if not UnitExists("target") then TM.Print("Pas de cible"); return end
    if not UnitIsPlayer("target") then TM.Print("La cible n'est pas un joueur"); return end
    local name = UnitName("target")
    if not name or name == "" then TM.Print("Impossible de récupérer le nom de la cible"); return end
    if not UnitIsConnected("target") then TM.Print("La cible n'est pas connectée"); return end
    local realm = GetRealmName() or ""
    local full = name
    if not full:match("%-") and realm ~= "" then full = full .. "-" .. realm end
    TM.AddMember(TM.selectedTeam, full, true)
    TM.SelectTeam(TM.selectedTeam)
    ui.memberInput:ClearFocus()
  end)

  local addGroupBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ui.addGroupBtn = addGroupBtn
  addGroupBtn:SetPoint("LEFT", addTargetBtn, "RIGHT", 6, 0)
  addGroupBtn:SetSize(100, 22)
  addGroupBtn:SetText("Add Group")
  addGroupBtn:SetScript("OnClick", function()
    if not TM.selectedTeam then TM.Print("Aucune équipe sélectionnée"); return end
    TM.AddGroupMembers(TM.selectedTeam); TM.SelectTeam(TM.selectedTeam)
    ui.memberInput:ClearFocus()
  end)

  local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ui.saveBtn = saveBtn
  saveBtn:SetPoint("LEFT", addGroupBtn, "RIGHT", 6, 0)
  saveBtn:SetSize(80, 22)
  saveBtn:SetText("Save")
  saveBtn:SetScript("OnClick", function()
    if not TM.db then TM.Print("Aucune donnée à sauvegarder"); return end
    TM.Print("ReloadUI() appelé pour forcer l'écriture des SavedVariables...")
    ui.teamName:ClearFocus(); ui.memberInput:ClearFocus()
    ReloadUI()
  end)

  -- OnShow: restore position, selection
  f:SetScript("OnShow", function()
    ui.teamName:ClearFocus(); ui.memberInput:ClearFocus()
    -- sync prefix field in case it was updated outside the UI
    if ui.prefixInput then ui.prefixInput:SetText(TM.SYNC_PREFIX) end
    TM.RefreshTeamList()
    if not TM.selectedTeam then
      local key   = TM.GetCharacterKey()
      local saved = TM.LoadSelectedTeamForCharacter()
      TM.DebugPrint("UI OnShow - vérification sauvegarde pour:", key, "->", tostring(saved))
      if saved and TM.db and TM.db.teams and TM.db.teams[saved] then
        TM.SelectTeam(saved, false)
        TM.Print("UI: Team restaurée pour ce personnage:", saved)
      else
        if TM.db and TM.db.teams then
          for nm, _ in pairs(TM.db.teams) do TM.SelectTeam(nm, false); break end
        end
      end
    end
  end)

  -- OnHide: persist position/size
  f:SetScript("OnHide", function(self)
    local point, _, relPoint, x, y = self:GetPoint()
    local data = { point = point, relPoint = relPoint, x = x, y = y,
                   width = self:GetWidth(), height = self:GetHeight() }
    local pcd = TM.GetPerCharDB()
    pcd.framePos    = data
    TM.db.framePos  = data
  end)

  -- Resize grip
  local resizeBtn = CreateFrame("Button", nil, f)
  resizeBtn:SetSize(16, 16)
  resizeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
  resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  resizeBtn:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
  end)
  resizeBtn:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
  ui.resizeBtn = resizeBtn

  -- Dynamic resize handler
  f:SetScript("OnSizeChanged", function(self, w, h)
    local lw  = math.max(160, math.floor(w * 0.28))
    local lih = h - 60
    local rw  = w - lw - 44
    local mh  = math.max(80, lih - 140)
    local iw  = math.max(140, rw - 220)
    local sw  = math.floor((w - lw - 52) / 2)
    if ui.listBG      then ui.listBG:SetSize(lw, lih) end
    if ui.listButtons then for _, b in ipairs(ui.listButtons) do b:SetWidth(lw - 20) end end
    if ui.membersFrame then
      ui.membersFrame:SetSize(sw, mh)
      if ui.memberRows then
        local labelW = sw - 16
        for _, row in ipairs(ui.memberRows) do row.nameLabel:SetWidth(labelW) end
      end
    end
    if ui.optionsBG   then ui.optionsBG:SetSize(sw, mh) end
    if ui.memberInput then ui.memberInput:SetWidth(iw) end
  end)

  TM.RefreshTeamList()
  TM.ApplyElvUISkin()
end

function TM.ToggleUI()
  TM.BuildUI()
  local f = TM.ui.frame
  if f:IsShown() then f:Hide() else f:Show() end
end

-- ────────────────────────────────────────────────────────────────────────────
-- Popup de confirmation d'invitation de team
-- Affiché quand un TEAM_INVITE est reçu et que la team est inconnue
-- ou que le préfixe sync ne correspond pas.
-- ────────────────────────────────────────────────────────────────────────────
function TM.ShowInviteConfirmDialog(data)
  local ui = TM.ui
  -- Réutilise le dialogue existant si déjà créé
  if ui.inviteConfirmDialog then
    local d = ui.inviteConfirmDialog
    d._data = data
    d.infoLine:SetText(string.format(
      "Équipe : |cffffcc00%s|r     Leader : |cffffcc00%s|r", data.teamName, data.leaderFull))
    d.prefixEdit:SetText(data.sentPrefix)
    d:Show()
    d.prefixEdit:SetFocus()
    return
  end

  local dialog = CreateFrame("Frame", "TeamManagerInviteDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(360, 190)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  dialog:SetClampedToScreen(true)
  dialog:SetMovable(true)
  dialog:EnableMouse(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
  dialog:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
  dialog:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  dialog:SetBackdropColor(0, 0, 0, 0.92)
  dialog._data = data

  -- Titre
  local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", dialog, "TOP", 0, -18)
  title:SetText("|cffffcc00TeamManager — Invitation reçue|r")

  -- Ligne d'information (team + leader)
  local infoLine = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  infoLine:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -46)
  infoLine:SetSize(320, 36)
  infoLine:SetJustifyH("LEFT")
  infoLine:SetText(string.format(
    "Équipe : |cffffcc00%s|r     Leader : |cffffcc00%s|r", data.teamName, data.leaderFull))
  dialog.infoLine = infoLine

  -- Instruction
  local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", infoLine, "BOTTOMLEFT", 0, -6)
  hint:SetSize(320, 20)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(0.7, 0.7, 0.7)
  hint:SetText("Saisissez le préfixe sync partagé avec le leader pour rejoindre :")

  -- Label préfixe
  local prefixLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  prefixLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
  prefixLabel:SetText("Préfixe sync :")

  -- Champ de saisie
  local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
  editBox:SetSize(190, 24)
  editBox:SetPoint("LEFT", prefixLabel, "RIGHT", 8, 0)
  editBox:SetAutoFocus(false)
  editBox:SetMaxLetters(16)
  editBox:SetText(data.sentPrefix)
  editBox:SetScript("OnEscapePressed", function(self) dialog:Hide() end)
  editBox:SetScript("OnEnterPressed",  function(self) dialog.confirmBtn:Click() end)
  dialog.prefixEdit = editBox

  -- Message d'erreur (caché par défaut)
  local errMsg = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  errMsg:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 20, 50)
  errMsg:SetSize(320, 18)
  errMsg:SetJustifyH("LEFT")
  errMsg:SetTextColor(1, 0.3, 0.3)
  errMsg:SetText("")
  dialog.errMsg = errMsg

  -- Bouton Confirmer
  local confirmBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  confirmBtn:SetSize(120, 26)
  confirmBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 24, 18)
  confirmBtn:SetText("Confirmer")
  confirmBtn:SetScript("OnClick", function()
    local entered = editBox:GetText():match("^%s*(.-)%s*$")
    local d = dialog._data
    if entered == d.sentPrefix then
      -- Crée ou met à jour la team à l'identique du leader
      if not TM.db.teams[d.teamName] then
        TM.db.teams[d.teamName] = { leader = d.leaderFull, members = {} }
      end
      local t = TM.db.teams[d.teamName]
      t.leader = d.leaderFull
      if d.membersStr and d.membersStr ~= "" then
        local newMembers = {}
        for m in d.membersStr:gmatch("[^,]+") do table.insert(newMembers, m) end
        t.members = newMembers
      end
      -- Met à jour le préfixe sync local pour correspondre au leader
      TM.SetSyncPrefix(d.sentPrefix)
      if ui.prefixInput then ui.prefixInput:SetText(TM.SYNC_PREFIX) end
      -- Active la team
      TM.selectedTeam = d.teamName
      TM.SaveSelectedTeamForCharacter(d.teamName)
      TM.Print("Team |cffffcc00" .. d.teamName .. "|r créée et activée. Préfixe sync : " .. d.sentPrefix)
      if ui.frame and ui.frame:IsShown() then
        TM.RefreshTeamList()
        TM.SelectTeam(d.teamName, false)
      end
      if TM.UpdateFloatingTeamLabel then TM.UpdateFloatingTeamLabel(d.teamName) end
      dialog:Hide()
    else
      dialog.errMsg:SetText("Préfixe incorrect — réessayez.")
      editBox:SetFocus()
    end
  end)
  dialog.confirmBtn = confirmBtn

  -- Bouton Annuler
  local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
  cancelBtn:SetSize(120, 26)
  cancelBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -24, 18)
  cancelBtn:SetText("Annuler")
  cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

  ui.inviteConfirmDialog = dialog
  dialog:Show()
  editBox:SetFocus()
end

