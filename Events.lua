-- TeamManager: Events — ADDON_LOADED, PLAYER_LOGIN, PLAYER_LOGOUT lifecycle

local addonName = ...

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    -- Re-sync with SavedVariables now that they are available
    TM.db = TeamManagerDB or { teams = {} }
    TeamManagerDB = TM.db
    TM.charDb = TeamManagerCharDB or {}
    TeamManagerCharDB = TM.charDb
    TM.debugEnabled = TM.db.debug or false
    -- Restore custom sync prefix if previously saved
    if TM.db.syncPrefix and TM.db.syncPrefix ~= "" then
      TM.SetSyncPrefix(TM.db.syncPrefix)
      local _ui = TM.ui
      if _ui and _ui.prefixInput then _ui.prefixInput:SetText(TM.SYNC_PREFIX) end
    end
    -- Try to restore per-character selection (pending, consumed at PLAYER_LOGIN)
    do
      local saved = TM.LoadSelectedTeamForCharacter()
      if saved and TM.db and TM.db.teams and TM.db.teams[saved] then
        TM.pendingSelectedTeam = saved
        TM.DebugPrint("(ADDON_LOADED) Team restaurée (pending):", saved)
      else
        TM.DebugPrint("(ADDON_LOADED) pas de team perChar restaurée")
      end
    end
    local count = 0
    if TM.db and TM.db.teams then for _ in pairs(TM.db.teams) do count = count + 1 end end
    TM.DebugPrint("ADDON_LOADED:", arg1, "équipes:", count)
    -- Update UI if already built
    local ui = TM.ui
    if ui and ui.frame then
      if ui.debugToggle then ui.debugToggle:SetChecked(TM.debugEnabled) end
      if ui.stateToggle then ui.stateToggle:SetChecked(TM.db.showStateDisplay ~= false) end
      if ui.questToggle then ui.questToggle:SetChecked(TM.db.autoAcceptQuest ~= false) end
      if ui.gossipToggle then ui.gossipToggle:SetChecked(TM.db.autoSelectGossip ~= false) end
      if ui.cinematicToggle then ui.cinematicToggle:SetChecked(TM.db.autoSkipCinematic ~= false) end
      if ui.taxiToggle then ui.taxiToggle:SetChecked(TM.db.autoTaxi ~= false) end
      if ui.instanceToggle then ui.instanceToggle:SetChecked(TM.db.autoEnterInstance ~= false) end
      TM.RefreshTeamList()
      if not TM.selectedTeam then
        local saved = TM.LoadSelectedTeamForCharacter()
        if saved and TM.db and TM.db.teams and TM.db.teams[saved] then
          TM.SelectTeam(saved, false)
          TM.Print("Team restaurée pour ce personnage:", saved)
        else
          for nm, _ in pairs(TM.db.teams) do TM.SelectTeam(nm, false); break end
        end
      end
      TM.AnnouncePlayerTeam()
    end

  elseif event == "PLAYER_LOGIN" then
    -- Re-sync SavedVariables (guaranteed available at login)
    TM.db = TeamManagerDB or { teams = {} }
    TeamManagerDB = TM.db
    TM.charDb = TeamManagerCharDB or {}
    TeamManagerCharDB = TM.charDb
    TM.debugEnabled = TM.db.debug or false
    -- Restore custom sync prefix if previously saved
    if TM.db.syncPrefix and TM.db.syncPrefix ~= "" then
      TM.SetSyncPrefix(TM.db.syncPrefix)
      local _ui = TM.ui
      if _ui and _ui.prefixInput then _ui.prefixInput:SetText(TM.SYNC_PREFIX) end
    end
    -- Restore persistent member cache
    if TM.db.memberCache then
      for k, v in pairs(TM.db.memberCache) do
        if not TM.memberXPCache[k] then TM.memberXPCache[k] = v end
      end
      TM.DebugPrint("memberCache restauré:", (function()
        local n = 0; for _ in pairs(TM.db.memberCache) do n = n + 1 end; return n
      end)(), "entrées")
    end
    local count = 0
    if TM.db and TM.db.teams then for _ in pairs(TM.db.teams) do count = count + 1 end end
    TM.Print("TeamManager chargé. /tm pour commandes. Équipes chargées:", count)
    TM.BroadcastXPSync()
    TM.BuildUI()
    local ui = TM.ui
    if ui.debugToggle then ui.debugToggle:SetChecked(TM.debugEnabled) end
    if ui.stateToggle then ui.stateToggle:SetChecked(TM.db.showStateDisplay ~= false) end
    if ui.questToggle then ui.questToggle:SetChecked(TM.db.autoAcceptQuest ~= false) end
    if ui.gossipToggle then ui.gossipToggle:SetChecked(TM.db.autoSelectGossip ~= false) end
    if ui.cinematicToggle then ui.cinematicToggle:SetChecked(TM.db.autoSkipCinematic ~= false) end
    if ui.taxiToggle then ui.taxiToggle:SetChecked(TM.db.autoTaxi ~= false) end
    if ui.instanceToggle then ui.instanceToggle:SetChecked(TM.db.autoEnterInstance ~= false) end
    TM.RefreshTeamList()
    -- Consume pending selection or restore from charDb
    local key = TM.GetCharacterKey()
    local saved = TM.LoadSelectedTeamForCharacter()
    TM.DebugPrint("Vérification sauvegarde pour:", key, "->", tostring(saved))
    TM.DebugPrint("TM.db.teams keys:")
    if TM.db and TM.db.teams then
      for k, _ in pairs(TM.db.teams) do TM.DebugPrint(" team:", k) end
    end
    if saved and TM.db and TM.db.teams and TM.db.teams[saved] then
      TM.SelectTeam(saved, false)
      TM.Print("Team restaurée pour ce personnage:", saved)
    else
      if TM.db and TM.db.teams then
        for name, _ in pairs(TM.db.teams) do TM.SelectTeam(name); break end
      end
    end
    -- Initialise le binding sécurisé assist après chargement des keybindings
    if TM.RefreshAssistBinding then TM.RefreshAssistBinding() end
  end
end)

-- Rafraîchit le binding assist si l'utilisateur change ses touches
local bindingsFrame = CreateFrame("Frame")
bindingsFrame:RegisterEvent("UPDATE_BINDINGS")
bindingsFrame:SetScript("OnEvent", function()
  if TM.RefreshAssistBinding then TM.RefreshAssistBinding() end
end)

-- selectedTeam: initialize after pending is potentially set by ADDON_LOADED
TM.selectedTeam = TM.pendingSelectedTeam or nil
TM.pendingSelectedTeam = nil

-- Minimap button + floating label restoration after login
local mmInit = CreateFrame("Frame")
mmInit:RegisterEvent("PLAYER_LOGIN")
mmInit:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    TM.CreateMinimapButton()
    local pcd = TM.GetPerCharDB()
    local fl = pcd.floatingLabel
    if fl and fl.teamName and fl.teamName ~= "" then
      TM.CreateFloatingTeamLabel(fl.teamName, fl.point, fl.relPoint, fl.x, fl.y)
      if fl.expanded then
        TM.RefreshFloatingMemberList()
        local ui = TM.ui
        if ui.floatingMemberList then ui.floatingMemberList:Show() end
      end
    end
  end
end)

-- Debug: report teams at logout
local logoutDbg = CreateFrame("Frame")
logoutDbg:RegisterEvent("PLAYER_LOGOUT")
logoutDbg:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGOUT" then
    local count = 0
    for _ in pairs(TM.db.teams) do count = count + 1 end
    TM.Print("PLAYER_LOGOUT - équipes en mémoire:", count)
  end
end)

-- Refresh secure assist button when group composition changes (unit tokens change)
local rosterFrame = CreateFrame("Frame")
rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterFrame:SetScript("OnEvent", function(self, event)
  if TM.UpdateAssistButton then TM.UpdateAssistButton() end
end)

-- Broadcast follow state changes (début et fin de follow)
local followFrame = CreateFrame("Frame")
followFrame:RegisterEvent("AUTOFOLLOW_BEGIN")
followFrame:RegisterEvent("AUTOFOLLOW_END")
followFrame:SetScript("OnEvent", function(self, event, unitName)
  if not TM.BroadcastMemberState then return end
  if event == "AUTOFOLLOW_BEGIN" then
    -- unitName est le nom court de la cible suivie
    local target = unitName or (UnitName("target") or "")
    TM.BroadcastMemberState("follow", target)
    TM.DebugPrint("AUTOFOLLOW_BEGIN: follow ->", target)
  elseif event == "AUTOFOLLOW_END" then
    TM.BroadcastMemberState("follow", nil)
    TM.DebugPrint("AUTOFOLLOW_END: follow effacé")
  end
end)

-- Effacer l'état assist si la cible du joueur change après un assist
local targetFrame = CreateFrame("Frame")
targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetFrame:SetScript("OnEvent", function(self, event)
  if not TM.BroadcastMemberState or not TM.memberStateCache then return end
  local me = UnitName("player")
  local currentState = TM.memberStateCache[me]
  if not currentState or not currentState.assist then return end
  -- Comparer la cible actuelle avec l'état assist enregistré
  local currentTarget = UnitName("target") or ""
  if currentTarget ~= currentState.assist then
    TM.BroadcastMemberState("assist", nil)
    TM.DebugPrint("PLAYER_TARGET_CHANGED: assist effacé (nouvelle cible:", currentTarget, ")")
  end
end)

-- Auto-accepter les quêtes si le leader accepte (si option activée)
local questAutoFrame = CreateFrame("Frame")
questAutoFrame:RegisterEvent("QUEST_ACCEPTED")
questAutoFrame:SetScript("OnEvent", function(self, event, questID)
  if not (TM.db and TM.db.autoAcceptQuest ~= false) then return end
  local teamName = TM.selectedTeam
  if not teamName then return end
  local t = TM.db.teams and TM.db.teams[teamName]
  if not t or not t.leader then return end
  local leaderShort = t.leader:match("^(.-)%-") or t.leader
  if leaderShort ~= UnitName("player") then return end
  if TM.BroadcastQuestAccept then
    TM.BroadcastQuestAccept(questID or 0)
  end
end)

-- Sélection automatique de dialogue PNJ (gossip) si le leader clique (si option activée)
-- On accroche C_GossipInfo.SelectOption (retail) et SelectGossipOption (classic/compat)
-- pour détecter le clic du leader et broadcaster aux membres.
local _gossipBroadcastPending = false

local function _onGossipSelect(optionID)
  if _gossipBroadcastPending then return end  -- éviter double broadcast
  if not (TM.db and TM.db.autoSelectGossip ~= false) then return end
  local teamName = TM.selectedTeam
  if not teamName then return end
  local t = TM.db.teams and TM.db.teams[teamName]
  if not t or not t.leader then return end
  local leaderShort = t.leader:match("^(.-)%-") or t.leader
  if leaderShort ~= UnitName("player") then return end
  _gossipBroadcastPending = true
  if TM.BroadcastGossipSelect then TM.BroadcastGossipSelect(optionID) end
  _gossipBroadcastPending = false
end

-- Hook retail (C_GossipInfo.SelectOption)
if C_GossipInfo and C_GossipInfo.SelectOption then
  hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
    _onGossipSelect(optionID)
  end)
end

-- Hook classic/compat (SelectGossipOption) — index converti en optionID si possible
if SelectGossipOption then
  hooksecurefunc("SelectGossipOption", function(index)
    -- En retail C_GossipInfo.SelectOption se déclenche aussi → guard via pending
    if _gossipBroadcastPending then return end
    local optionID = index  -- fallback : utiliser l'index comme identifiant
    if C_GossipInfo and C_GossipInfo.GetOptions then
      local opts = C_GossipInfo.GetOptions()
      if opts and opts[index] then optionID = opts[index].gossipOptionID or index end
    end
    _onGossipSelect(optionID)
  end)
end

-- Passer les cinématiques automatiquement si le leader passe (option activée)
local function _isLeader()
  if not TM.selectedTeam then return false end
  local t = TM.db and TM.db.teams and TM.db.teams[TM.selectedTeam]
  if not t or not t.leader then return false end
  local leaderShort = t.leader:match("^(.-)%-") or t.leader
  return leaderShort == UnitName("player")
end

hooksecurefunc("CancelCinematic", function()
  if not (TM.db and TM.db.autoSkipCinematic ~= false) then return end
  if not _isLeader() then return end
  if TM.BroadcastCinematicSkip then TM.BroadcastCinematicSkip("cinematic") end
end)

if StopMovie then
  hooksecurefunc("StopMovie", function()
    if not (TM.db and TM.db.autoSkipCinematic ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastCinematicSkip then TM.BroadcastCinematicSkip("movie") end
  end)
end

-- Maître de vol automatique : broadcaster la destination choisie par le leader
hooksecurefunc("TakeTaxiNode", function(nodeIndex)
  if not (TM.db and TM.db.autoTaxi ~= false) then return end
  if not _isLeader() then return end
  if TM.BroadcastTaxiNode then TM.BroadcastTaxiNode(nodeIndex) end
end)

-- Entrée d'instance automatique : broadcaster quand le leader valide
-- Cas 1 : proposition LFG (popup donjon prêt) — AcceptProposal
hooksecurefunc("AcceptProposal", function()
  TM.DebugPrint("AcceptProposal déclenché (leader=", tostring(_isLeader()), ")")
  if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
  if not _isLeader() then return end
  if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("lfg") end
end)

-- Cas 2 : portail de donjon dans le monde — ConfirmEnterInstance
if ConfirmEnterInstance then
  hooksecurefunc("ConfirmEnterInstance", function()
    if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("portal") end
  end)
end

-- Cas 3 : Gouffres (Delves, TWW) + popups classiques
-- Les Delves TWW n'utilisent PAS de StaticPopup Lua — on détecte l'entrée
-- via PLAYER_ENTERING_WORLD côté leader, et LFG_PROPOSAL_SHOW côté membre.

-- DEBUG : log tous les StaticPopup_Show pour identification future
hooksecurefunc("StaticPopup_Show", function(which)
  if TM.debugEnabled then TM.DebugPrint("StaticPopup_Show:", which) end
end)

-- Fallback StaticPopup_OnClick (portails / popups classiques)
hooksecurefunc("StaticPopup_OnClick", function(self, whichButton)
  if whichButton ~= 1 then return end
  if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
  if not _isLeader() then return end
  local which = self.which or ""
  TM.DebugPrint("StaticPopup_OnClick which=", which)
  if which:find("DELVE") then
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("delve") end
  elseif which:find("INSTANCE") or which:find("LOCK") then
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("portal") end
  end
end)

-- Détection principale pour Delves TWW :
-- quand le leader entre dans une instance (PLAYER_ENTERING_WORLD), broadcaster.
local _lastBroadcastInstance = 0
local delveDetectFrame = CreateFrame("Frame")
delveDetectFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
delveDetectFrame:SetScript("OnEvent", function()
  -- Toujours logger pour diagnostic (même si les checks échouent)
  TM.DebugPrint("PLAYER_ENTERING_WORLD déclenché (autoEnterInstance=",
    tostring(TM.db and TM.db.autoEnterInstance ~= false),
    ", isLeader=", tostring(_isLeader()), ")")
  if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
  if not _isLeader() then return end
  C_Timer.After(0.3, function()
    local inInstance, instanceType = IsInInstance()
    TM.DebugPrint("PLAYER_ENTERING_WORLD +0.3s: inInstance=", tostring(inInstance), "type=", tostring(instanceType))
    if not inInstance then return end
    local now = GetTime()
    if (now - _lastBroadcastInstance) < 10 then
      TM.DebugPrint("PLAYER_ENTERING_WORLD: anti-spam actif, skip broadcast")
      return
    end
    _lastBroadcastInstance = now
    TM.DebugPrint("PLAYER_ENTERING_WORLD: leader entré instance type=", instanceType, "-> broadcast delve")
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("delve") end
  end)
end)

-- Côté membre : auto-accepter LFG_PROPOSAL_SHOW directement si autoEnterInstance activé.
-- Ne dépend PAS du flag pending — un membre en équipe accepte tout proposal d'instance.
TM.pendingInstanceAccept = false
local lfgAutoAcceptFrame = CreateFrame("Frame")
lfgAutoAcceptFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
lfgAutoAcceptFrame:SetScript("OnEvent", function()
  if not (TM.db and TM.db.autoEnterInstance ~= false) then
    TM.DebugPrint("LFG_PROPOSAL_SHOW: autoEnterInstance désactivé, skip")
    return
  end
  if _isLeader() then
    TM.DebugPrint("LFG_PROPOSAL_SHOW: je suis leader, pas d'auto-accept membre")
    return
  end
  TM.DebugPrint("LFG_PROPOSAL_SHOW: membre -> auto-accept proposal")
  pcall(AcceptProposal)
end)
