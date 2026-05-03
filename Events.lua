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
      if ui.validateQuestToggle then ui.validateQuestToggle:SetChecked(TM.db.autoValidateQuest ~= false) end
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
        end
        -- Pas de fallback : un perso sans team sauvegardée ne doit pas hériter d'une team étrangère
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
    if ui.validateQuestToggle then ui.validateQuestToggle:SetChecked(TM.db.autoValidateQuest ~= false) end
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
    end
    -- Pas de fallback : un perso sans team sauvegardée ne doit pas hériter d'une team étrangère
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
local function _isLeader()
  if not TM.selectedTeam then return false end
  local t = TM.db and TM.db.teams and TM.db.teams[TM.selectedTeam]
  if not t or not t.leader then return false end
  local leaderShort = t.leader:match("^(.-)%-") or t.leader
  return leaderShort == UnitName("player")
end

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

-- Auto-valider (remettre) les quêtes si le leader valide (si option activée)
-- L'UI Blizzard appelle CompleteQuest() depuis QuestProgressCompleteButton_OnClick
-- et GetQuestReward(choice) depuis QuestRewardCompleteButton_OnClick
-- (cf. wow-ui-source/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua).
-- On hooke en priorité le clic des BOUTONS UI (path le plus fiable et utilisé par le
-- joueur en pratique), et on garde un hook sur les globales en filet de sécurité.
local _questValidateBroadcastPending = false
local _questRewardBroadcastPending   = false

local function _broadcastQuestValidateOnce()
  if _questValidateBroadcastPending then return end
  if not (TM.db and TM.db.autoValidateQuest ~= false) then return end
  if not _isLeader() then return end
  _questValidateBroadcastPending = true
  local questID = (GetQuestID and GetQuestID()) or 0
  if TM.BroadcastQuestValidate then TM.BroadcastQuestValidate(questID) end
  TM.DebugPrint("Broadcast QVALIDATE questID=", questID)
  -- Reset flag après la frame courante (les hooks UI/globaux peuvent se chaîner)
  C_Timer.After(0, function() _questValidateBroadcastPending = false end)
end

local function _broadcastQuestRewardOnce(choice)
  if _questRewardBroadcastPending then return end
  if not (TM.db and TM.db.autoValidateQuest ~= false) then return end
  if not _isLeader() then return end
  _questRewardBroadcastPending = true
  local questID = (GetQuestID and GetQuestID()) or 0
  if TM.BroadcastQuestReward then TM.BroadcastQuestReward(questID, choice or 0) end
  TM.DebugPrint("Broadcast QREWARD questID=", questID, "choice=", choice)
  C_Timer.After(0, function() _questRewardBroadcastPending = false end)
end

-- Hook 1 (prioritaire) : clic du bouton "Continuer" sur le panel de progression
if QuestFrameCompleteButton then
  QuestFrameCompleteButton:HookScript("OnClick", function()
    TM.DebugPrint("QuestFrameCompleteButton OnClick (panel progression)")
    _broadcastQuestValidateOnce()
  end)
end

-- Hook 2 (prioritaire) : clic du bouton "Terminer la quête" sur le panel de récompenses
if QuestFrameCompleteQuestButton then
  QuestFrameCompleteQuestButton:HookScript("OnClick", function()
    TM.DebugPrint("QuestFrameCompleteQuestButton OnClick (panel récompenses)")
    local choice = (QuestInfoFrame and QuestInfoFrame.itemChoice) or 0
    _broadcastQuestRewardOnce(choice)
  end)
end

-- Hook 3 (filet de sécurité) : appel direct du global CompleteQuest()
if CompleteQuest then
  hooksecurefunc("CompleteQuest", function()
    TM.DebugPrint("hooksecurefunc CompleteQuest")
    _broadcastQuestValidateOnce()
  end)
end

-- Hook 4 (filet de sécurité) : appel direct du global GetQuestReward()
if GetQuestReward then
  hooksecurefunc("GetQuestReward", function(choice)
    TM.DebugPrint("hooksecurefunc GetQuestReward choice=", choice)
    _broadcastQuestRewardOnce(choice)
  end)
end

-- Hook 5 (filet ultime) : événement serveur QUEST_TURNED_IN
-- Cet event est émis par le serveur APRÈS qu'une quête est remise, indépendamment
-- de l'UI utilisée (Blizzard, DialogueUI, etc.). On l'utilise pour broadcaster aux
-- membres au cas où aucun des hooks précédents n'aurait capté la remise.
-- NB : la quête est déjà remise sur le leader → les membres qui ont le panel ouvert
-- valident en réaction. Le `choice` n'est pas connu (toujours 0) → suffisant si la
-- quête a une seule récompense ou aucune.
local questTurnedInFrame = CreateFrame("Frame")
questTurnedInFrame:RegisterEvent("QUEST_TURNED_IN")
questTurnedInFrame:SetScript("OnEvent", function(self, event, questID)
  TM.DebugPrint("QUEST_TURNED_IN event questID=", questID)
  if not (TM.db and TM.db.autoValidateQuest ~= false) then return end
  if not _isLeader() then return end
  -- Broadcast les deux étapes en cascade : QVALIDATE puis QREWARD
  -- Le membre qui aurait raté QVALIDATE bénéficiera du QREWARD direct
  if TM.BroadcastQuestValidate and not _questValidateBroadcastPending then
    _questValidateBroadcastPending = true
    TM.BroadcastQuestValidate(questID or 0)
    TM.DebugPrint("Broadcast QVALIDATE (QUEST_TURNED_IN) questID=", questID)
    C_Timer.After(0, function() _questValidateBroadcastPending = false end)
  end
  if TM.BroadcastQuestReward and not _questRewardBroadcastPending then
    _questRewardBroadcastPending = true
    TM.BroadcastQuestReward(questID or 0, 0)
    TM.DebugPrint("Broadcast QREWARD (QUEST_TURNED_IN) questID=", questID)
    C_Timer.After(0, function() _questRewardBroadcastPending = false end)
  end
end)

-- Diagnostic au chargement (uniquement si debug activé)
C_Timer.After(3, function()
  TM.DebugPrint("Quest hooks status:",
    "CompleteButton=", tostring(QuestFrameCompleteButton ~= nil),
    "CompleteQuestButton=", tostring(QuestFrameCompleteQuestButton ~= nil),
    "CompleteQuest=", tostring(CompleteQuest ~= nil),
    "GetQuestReward=", tostring(GetQuestReward ~= nil))
end)

-- Sélection automatique de dialogue PNJ (gossip) si le leader clique (si option activée)
-- En retail, le clic sur une option appelle C_GossipInfo.SelectOptionByIndex(orderIndex)
-- (cf. wow-ui-source GossipOptionButtonMixin:OnClick). On hooke donc en priorité cette
-- fonction, on résout l'orderIndex en gossipOptionID (server-stable, cross-player) et on
-- broadcast cet ID. C_GossipInfo.SelectOption et SelectGossipOption restent hookés pour
-- les cas marginaux.
local _gossipBroadcastPending = false

local function _resolveGossipOptionID(orderIndex)
  if not (C_GossipInfo and C_GossipInfo.GetOptions) then return nil end
  local opts = C_GossipInfo.GetOptions()
  if not opts then return nil end
  -- Cas 1 : opts[i].orderIndex == orderIndex (retail courant)
  for _, info in ipairs(opts) do
    if info.orderIndex == orderIndex then return info.gossipOptionID end
  end
  -- Cas 2 : fallback positionnel (classic ou table non-triée)
  if opts[orderIndex] then return opts[orderIndex].gossipOptionID end
  return nil
end

local function _onGossipBroadcast(gossipOptionID, source)
  TM.DebugPrint("[GossipHook]", source or "?", "gossipOptionID=", tostring(gossipOptionID),
    "isLeader=", tostring(_isLeader()),
    "autoSelectGossip=", tostring(TM.db and TM.db.autoSelectGossip))
  if _gossipBroadcastPending then return end
  if not gossipOptionID then return end
  if not (TM.db and TM.db.autoSelectGossip ~= false) then return end
  if not _isLeader() then return end
  _gossipBroadcastPending = true
  if TM.BroadcastGossipSelect then TM.BroadcastGossipSelect(gossipOptionID) end
  _gossipBroadcastPending = false
end

-- Hook principal retail : C_GossipInfo.SelectOptionByIndex(orderIndex)
if C_GossipInfo and C_GossipInfo.SelectOptionByIndex then
  hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(orderIndex)
    local gid = _resolveGossipOptionID(orderIndex)
    _onGossipBroadcast(gid, "SelectOptionByIndex(" .. tostring(orderIndex) .. ")")
  end)
end

-- Hook secondaire : C_GossipInfo.SelectOption(gossipOptionID, ...) (appel direct)
if C_GossipInfo and C_GossipInfo.SelectOption then
  hooksecurefunc(C_GossipInfo, "SelectOption", function(gossipOptionID)
    _onGossipBroadcast(gossipOptionID, "C_GossipInfo.SelectOption")
  end)
end

-- Hook classic/compat : SelectGossipOption(index) -- 1-based dans la liste triée
if SelectGossipOption then
  hooksecurefunc("SelectGossipOption", function(index)
    local gid = _resolveGossipOptionID(index) or index
    _onGossipBroadcast(gid, "SelectGossipOption(" .. tostring(index) .. ")")
  end)
end

-- Passer les cinématiques automatiquement si le leader passe (option activée)
-- API réelles (cf. wow-ui-source/Blizzard_FrameXML/Shared/CinematicFrame.lua
-- et Blizzard_FrameXML/MovieFrame.lua) :
--   * Cinématique moteur : ESC → CinematicFrame_CancelCinematic() → StopCinematic()
--     (`CancelCinematic` n'existe PAS comme API globale)
--   * Vidéo pré-rendue   : ESC → closeDialog → MovieFrame:FinishMovie()
--     (`StopMovie` global n'existe PAS, c'est une méthode du widget Movie)
if StopCinematic then
  hooksecurefunc("StopCinematic", function()
    TM.DebugPrint("[CinematicHook] StopCinematic isLeader=", tostring(_isLeader()),
      "autoSkipCinematic=", tostring(TM.db and TM.db.autoSkipCinematic))
    if not (TM.db and TM.db.autoSkipCinematic ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastCinematicSkip then TM.BroadcastCinematicSkip("cinematic") end
  end)
end
-- Hook secondaire sur le wrapper Lua (au cas où un addon court-circuite StopCinematic)
if CinematicFrame_CancelCinematic then
  hooksecurefunc("CinematicFrame_CancelCinematic", function()
    TM.DebugPrint("[CinematicHook] CinematicFrame_CancelCinematic isLeader=", tostring(_isLeader()))
    if not (TM.db and TM.db.autoSkipCinematic ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastCinematicSkip then TM.BroadcastCinematicSkip("cinematic") end
  end)
end

-- Vidéo pré-rendue : MovieFrame:FinishMovie() est appelé quel que soit le mode
-- de sortie (ESC+confirm, fin naturelle, OnHide). On hooke la méthode du mixin.
if MovieFrame and MovieFrame.FinishMovie then
  hooksecurefunc(MovieFrame, "FinishMovie", function()
    TM.DebugPrint("[CinematicHook] MovieFrame:FinishMovie isLeader=", tostring(_isLeader()),
      "autoSkipCinematic=", tostring(TM.db and TM.db.autoSkipCinematic))
    if not (TM.db and TM.db.autoSkipCinematic ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastCinematicSkip then TM.BroadcastCinematicSkip("movie") end
  end)
end

-- Maître de vol automatique : broadcaster la destination choisie par le leader
if TakeTaxiNode then
  hooksecurefunc("TakeTaxiNode", function(nodeIndex)
    if not (TM.db and TM.db.autoTaxi ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastTaxiNode then TM.BroadcastTaxiNode(nodeIndex) end
  end)
end

-- Entrée d'instance automatique : broadcaster quand le leader valide
-- Cas 1 : proposition LFG (popup donjon prêt) — AcceptProposal
-- Guarded: AcceptProposal may not exist in all TWW builds; a nil hook would Lua-error
-- and prevent all subsequent code (including delveDetectFrame) from loading.
if AcceptProposal then
  hooksecurefunc("AcceptProposal", function()
    TM.DebugPrint("AcceptProposal déclenché (leader=", tostring(_isLeader()), ")")
    if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("lfg") end
  end)
else
  TM.DebugPrint("AcceptProposal absent de l'API TWW — hook LFG désactivé")
end

-- Cas 2 : portail de donjon dans le monde — ConfirmEnterInstance
if ConfirmEnterInstance then
  hooksecurefunc("ConfirmEnterInstance", function()
    if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("portal") end
  end)
end

-- Cas 2b : entrée directe de Gouffre (Delve TWW) via C_DelvesUI.SelectDelveEntranceTier
-- Hookée sur la table C_DelvesUI : pas de StaticPopup, pas d'event LFG.
if C_DelvesUI and C_DelvesUI.SelectDelveEntranceTier then
  hooksecurefunc(C_DelvesUI, "SelectDelveEntranceTier", function(tier)
    if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastDelveEnter then TM.BroadcastDelveEnter(tier) end
  end)
end

-- Cas 3 : Gouffres (Delves, TWW) + popups classiques
-- Les Delves TWW n'utilisent PAS de StaticPopup Lua — on détecte l'entrée
-- via PLAYER_ENTERING_WORLD côté leader, et LFG_PROPOSAL_SHOW côté membre.

-- DEBUG : log tous les StaticPopup_Show pour identification future (guarded)
if StaticPopup_Show then
  hooksecurefunc("StaticPopup_Show", function(which)
    if TM.debugEnabled then TM.DebugPrint("StaticPopup_Show:", which) end
  end)
else
  TM.DebugPrint("StaticPopup_Show absent — hook désactivé")
end

-- Fallback StaticPopup_OnClick (portails / popups classiques + sortie de Gouffre) (guarded)
-- Logique : si le leader EST dans une instance (scénario = Gouffre TWW) → sortie.
--           si le leader N'EST PAS dans une instance → entrée (entrée donjon/delve).
if StaticPopup_OnClick then
  local _lastBroadcastDelveExit = 0
  hooksecurefunc("StaticPopup_OnClick", function(self, whichButton)
    if whichButton ~= 1 then return end
    if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
    if not _isLeader() then return end
    local which = self.which or ""
    TM.DebugPrint("StaticPopup_OnClick which=", which)
    local inInst, instType = IsInInstance()
    if inInst then
      -- Leader dans une instance → c'est une sortie de Gouffre
      local now = GetTime()
      if (now - _lastBroadcastDelveExit) >= 5 then
        _lastBroadcastDelveExit = now
        TM.DebugPrint("Sortie Gouffre (instType=", instType, "which=", which, ") -> broadcast DELVEEXIT")
        if TM.BroadcastDelveExit then TM.BroadcastDelveExit() end
      end
    else
      -- Leader hors instance → c'est une entrée
      if which:find("DELVE") then
        if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("delve") end
      elseif which:find("INSTANCE") or which:find("LOCK") then
        if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("portal") end
      end
    end
  end)
else
  TM.DebugPrint("StaticPopup_OnClick absent — hook désactivé")
end

-- Détection d'entrée dans un Gouffre (Delve TWW) :
-- PLAYER_ENTERING_WORLD peut ne pas fire lors des transitions Delve en TWW ;
-- ZONE_CHANGED_NEW_AREA est plus fiable car il fire après le loading screen.
local _lastBroadcastInstance = 0
local delveDetectFrame = CreateFrame("Frame")
delveDetectFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
delveDetectFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
delveDetectFrame:SetScript("OnEvent", function(self, event)
  TM.DebugPrint(event, "autoEnterInstance=", tostring(TM.db and TM.db.autoEnterInstance ~= false), "isLeader=", tostring(_isLeader()))
  if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
  if not _isLeader() then return end
  -- Délai 1s : laisser le serveur confirmer l'état d'instance
  C_Timer.After(1, function()
    local inInstance, instanceType = IsInInstance()
    TM.DebugPrint("+1s: inInstance=", tostring(inInstance), "type=", tostring(instanceType))
    if not inInstance then return end
    local now = GetTime()
    if (now - _lastBroadcastInstance) < 10 then
      TM.DebugPrint("anti-spam actif, skip broadcast")
      return
    end
    _lastBroadcastInstance = now
    TM.DebugPrint("leader entré instance type=", instanceType, "-> broadcast delve")
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("delve") end
  end)
end)

-- Côté membre : auto-accepter LFG_PROPOSAL_SHOW directement si autoEnterInstance activé.
TM.pendingInstanceAccept = false
local lfgAutoAcceptFrame = CreateFrame("Frame")
lfgAutoAcceptFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
lfgAutoAcceptFrame:SetScript("OnEvent", function()
  TM.Print("[DIAG] LFG_PROPOSAL_SHOW reçu")
  -- Hook unique sur EnterDungeonButton pour vérifier si Click() lui parvient
  local enterBtn = _G["LFGDungeonReadyDialogEnterDungeonButton"]
  if enterBtn and not enterBtn._tmHooked then
    enterBtn._tmHooked = true
    enterBtn:HookScript("OnClick", function()
      TM.Print("[DIAG] LFGDungeonReadyDialogEnterDungeonButton:OnClick fired!")
    end)
    TM.Print("[DIAG] Hook EnterDungeonButton:OnClick installé")
  end
  -- Scan récursif de tous les boutons enfants de LFGDungeonReadyDialog (profondeur 4)
  local dlg = _G["LFGDungeonReadyDialog"]
  if dlg and dlg:IsShown() then
    TM.Print("[DIAG] Scan LFGDungeonReadyDialog (récursif, shown seulement):")
    local function scanBtn(f, depth)
      if depth > 4 then return end
      for _, child in ipairs({f:GetChildren()}) do
        local shown = child:IsShown()
        local otype = child:GetObjectType()
        if otype == "Button" or shown then
          TM.Print("[DIAG] d=" .. depth,
            otype, tostring(child:GetName()),
            "shown=", tostring(shown),
            "enabled=", tostring(child.IsEnabled and child:IsEnabled() or "?"))
        end
        if shown then scanBtn(child, depth + 1) end
      end
    end
    scanBtn(dlg, 1)
  end
  if not (TM.db and TM.db.autoEnterInstance ~= false) then return end
  if _isLeader() then return end
  TM.AcceptInstanceProposal()
end)
