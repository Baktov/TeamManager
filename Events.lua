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
      if ui.dungeonToggle then ui.dungeonToggle:SetChecked(TM.db.autoEnterDungeon ~= false) end
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
    if ui.dungeonToggle then ui.dungeonToggle:SetChecked(TM.db.autoEnterDungeon ~= false) end
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
  -- Diagnostic systématique : permet de voir quand l'event fire et pourquoi le
  -- broadcast est éventuellement bloqué (utile car DialogueUI/Immersion peuvent
  -- court-circuiter nos hooks AcceptQuest/QuestFrameAcceptButton ; QUEST_ACCEPTED
  -- reste, lui, fiable car émis par le serveur).
  TM.DebugPrint("[QUEST_ACCEPTED] questID=", tostring(questID),
    "autoAcceptQuest=", tostring(TM.db and TM.db.autoAcceptQuest),
    "selectedTeam=", tostring(TM.selectedTeam),
    "isLeader=", tostring(_isLeader()),
    "inGroup=", tostring(IsInGroup()))
  if not (TM.db and TM.db.autoAcceptQuest ~= false) then return end
  if not _isLeader() then return end
  if TM.BroadcastQuestAccept then
    TM.BroadcastQuestAccept(questID or 0)
  end
end)

-- Filet de sécurité : hook direct sur AcceptQuest() + clic du bouton "Continuer/Accepter".
-- Avec DialogueUI/Immersion ou certaines quêtes campagne (page de prérequis), QUEST_ACCEPTED
-- peut être consommé par l'UI tierce ou retardé. On broadcaste donc aussi dès l'appel à
-- AcceptQuest, en utilisant GetQuestID() pour récupérer l'ID de la quête en cours de détail.
local _questAcceptBroadcastPending = false
local function _broadcastQuestAcceptOnce(reason)
  if _questAcceptBroadcastPending then return end
  if not (TM.db and TM.db.autoAcceptQuest ~= false) then return end
  if not _isLeader() then return end
  local questID = (GetQuestID and GetQuestID()) or 0
  if questID == 0 then
    TM.DebugPrint("[QuestAcceptHook] questID=0, skip broadcast (", reason, ")")
    return
  end
  _questAcceptBroadcastPending = true
  if TM.BroadcastQuestAccept then TM.BroadcastQuestAccept(questID) end
  TM.DebugPrint("[QuestAcceptHook]", reason, "questID=", questID)
  C_Timer.After(0, function() _questAcceptBroadcastPending = false end)
end

if AcceptQuest then
  hooksecurefunc("AcceptQuest", function()
    _broadcastQuestAcceptOnce("AcceptQuest()")
  end)
end

-- Clic du bouton "Continuer/Accepter" du panneau de détail de quête (path UI Blizzard)
if QuestFrameAcceptButton then
  QuestFrameAcceptButton:HookScript("OnClick", function()
    _broadcastQuestAcceptOnce("QuestFrameAcceptButton:OnClick")
  end)
end

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

-- Résout l'argument passé à C_GossipInfo.SelectOptionByIndex en gossipOptionID server-stable.
-- IMPORTANT : contrairement à ce que son nom suggère, l'argument de SelectOptionByIndex
-- est l'`orderIndex` (clé de tri renvoyée par le serveur, souvent 0-based ou non-contiguë),
-- PAS un luaIndex 1-based. Cf. wow-ui-source/Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua
-- (`self:SetID(optionInfo.orderIndex or 0)` puis `C_GossipInfo.SelectOptionByIndex(self:GetID())`)
-- et DialogueUI/Code/Dialogue/UITemplates.lua (`self.id = data.orderIndex` puis
-- `C_GossipInfo.SelectOptionByIndex(gossipButton.id)`).
-- On cherche donc d'abord une option dont `info.orderIndex` correspond, puis on retombe
-- sur la position 1-based en filet de sécurité.
local function _resolveGossipOptionID(orderIndex)
  if not (C_GossipInfo and C_GossipInfo.GetOptions) then return nil end
  local opts = C_GossipInfo.GetOptions()
  if not opts or orderIndex == nil then return nil end
  -- 1) Match par orderIndex (chemin nominal en retail et avec DialogueUI)
  for _, info in ipairs(opts) do
    if (info.orderIndex or -1) == orderIndex and info.gossipOptionID then
      return info.gossipOptionID
    end
  end
  -- 2) Fallback : position directe dans le tableau (rare, addons "exotiques")
  if opts[orderIndex] and opts[orderIndex].gossipOptionID then
    return opts[orderIndex].gossipOptionID
  end
  -- 3) Dernier filet : tri par orderIndex puis indexation 1-based
  local sorted = {}
  for _, info in ipairs(opts) do sorted[#sorted + 1] = info end
  table.sort(sorted, function(a, b)
    return (a.orderIndex or 0) < (b.orderIndex or 0)
  end)
  if sorted[orderIndex] then return sorted[orderIndex].gossipOptionID end
  return nil
end

local function _onGossipBroadcast(gossipOptionID, orderIndex, source)
  TM.DebugPrint("[GossipHook]", source or "?",
    "gossipOptionID=", tostring(gossipOptionID),
    "orderIndex=", tostring(orderIndex),
    "isLeader=", tostring(_isLeader()),
    "autoSelectGossip=", tostring(TM.db and TM.db.autoSelectGossip))
  if _gossipBroadcastPending then return end
  -- On accepte l'envoi tant qu'on a au moins un des deux (gossipOptionID OU orderIndex).
  -- Cas DialogueUI hint : gossipOptionID est nil/0 mais orderIndex est valide.
  if (not gossipOptionID or gossipOptionID == 0) and not orderIndex then return end
  if not (TM.db and TM.db.autoSelectGossip ~= false) then return end
  if not _isLeader() then return end
  _gossipBroadcastPending = true
  if TM.BroadcastGossipSelect then TM.BroadcastGossipSelect(gossipOptionID, orderIndex) end
  _gossipBroadcastPending = false
end

-- Hook principal retail : C_GossipInfo.SelectOptionByIndex(orderIndex)
if C_GossipInfo and C_GossipInfo.SelectOptionByIndex then
  hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(orderIndex)
    local gid = _resolveGossipOptionID(orderIndex)
    _onGossipBroadcast(gid, orderIndex, "SelectOptionByIndex(" .. tostring(orderIndex) .. ")")
  end)
end

-- Hook secondaire : C_GossipInfo.SelectOption(gossipOptionID, ...) (appel direct)
if C_GossipInfo and C_GossipInfo.SelectOption then
  hooksecurefunc(C_GossipInfo, "SelectOption", function(gossipOptionID)
    _onGossipBroadcast(gossipOptionID, nil, "C_GossipInfo.SelectOption")
  end)
end

-- Hook classic/compat : SelectGossipOption(index)
if SelectGossipOption then
  hooksecurefunc("SelectGossipOption", function(index)
    local gid = _resolveGossipOptionID(index)
    _onGossipBroadcast(gid, index, "SelectGossipOption(" .. tostring(index) .. ")")
  end)
end

-- ─── Hooks "quêtes disponibles / actives" depuis un PNJ gossip ─────────────
-- Le clic dans le GossipFrame sur une quête (icône ? jaune ou dorée) appelle
-- C_GossipInfo.SelectAvailableQuest(questID) ou SelectActiveQuest(questID),
-- PAS C_GossipInfo.SelectOption. Sans ces hooks, l'option "quête" du leader
-- n'est jamais répliquée chez les membres (donc pas de QACCEPT non plus).
local _gossipQuestBroadcastPending = false
local function _broadcastGossipQuest(kind, questID)
  if _gossipQuestBroadcastPending then return end
  if not questID or questID == 0 then return end
  if not (TM.db and TM.db.autoSelectGossip ~= false) then return end
  if not _isLeader() then return end
  _gossipQuestBroadcastPending = true
  if kind == "available" and TM.BroadcastGossipQuestAvailable then
    TM.BroadcastGossipQuestAvailable(questID)
  elseif kind == "active" and TM.BroadcastGossipQuestActive then
    TM.BroadcastGossipQuestActive(questID)
  end
  C_Timer.After(0, function() _gossipQuestBroadcastPending = false end)
end

if C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
  hooksecurefunc(C_GossipInfo, "SelectAvailableQuest", function(questID)
    TM.DebugPrint("[GossipHook] SelectAvailableQuest questID=", tostring(questID))
    _broadcastGossipQuest("available", questID)
  end)
end

if C_GossipInfo and C_GossipInfo.SelectActiveQuest then
  hooksecurefunc(C_GossipInfo, "SelectActiveQuest", function(questID)
    TM.DebugPrint("[GossipHook] SelectActiveQuest questID=", tostring(questID))
    _broadcastGossipQuest("active", questID)
  end)
end

-- Legacy (classic) : SelectGossipAvailableQuest/SelectGossipActiveQuest reçoivent un index ;
-- on résout via C_GossipInfo.GetAvailableQuests/GetActiveQuests pour obtenir le questID.
if SelectGossipAvailableQuest and C_GossipInfo and C_GossipInfo.GetAvailableQuests then
  hooksecurefunc("SelectGossipAvailableQuest", function(index)
    local list = C_GossipInfo.GetAvailableQuests() or {}
    local info = list[index]
    if info and info.questID then _broadcastGossipQuest("available", info.questID) end
  end)
end

if SelectGossipActiveQuest and C_GossipInfo and C_GossipInfo.GetActiveQuests then
  hooksecurefunc("SelectGossipActiveQuest", function(index)
    local list = C_GossipInfo.GetActiveQuests() or {}
    local info = list[index]
    if info and info.questID then _broadcastGossipQuest("active", info.questID) end
  end)
end

-- ─── Hook fermeture DialogueUI : broadcast CLOSEUI au membre ───────────────
-- DialogueUI ne s'expose pas dans _G ; on attache son OnHide via EnumerateFrames
-- au PLAYER_LOGIN +5s (le frame est créé au premier GOSSIP_SHOW, mais on tente
-- aussi à chaque GOSSIP_SHOW si pas encore trouvé).
local _dialogueCloseHookInstalled = false
local _lastDialogueCloseBroadcast = 0
local function _tryHookDialogueUIClose()
  if _dialogueCloseHookInstalled then return true end
  if not TM.FindDialogueUIFrame then return false end
  local f = TM.FindDialogueUIFrame()
  if not f then return false end
  f:HookScript("OnHide", function()
    if not (TM.db and TM.db.autoSelectGossip ~= false) then return end
    if not _isLeader() then return end
    -- Anti-spam : ne broadcast qu'une fois toutes les 2s.
    local now = GetTime()
    if (now - _lastDialogueCloseBroadcast) < 2 then return end
    _lastDialogueCloseBroadcast = now
    if TM.BroadcastDialogClose then TM.BroadcastDialogClose() end
    TM.DebugPrint("[DialogueUIHook] OnHide -> CLOSEUI broadcasté")
  end)
  _dialogueCloseHookInstalled = true
  TM.DebugPrint("[DialogueUIHook] OnHide hook installé sur DialogueUI frame")
  return true
end

-- Tentative à chargement (DialogueUI peut déjà être chargé)
C_Timer.After(5, _tryHookDialogueUIClose)

-- Tentative à chaque GOSSIP_SHOW (DialogueUI crée son frame paresseusement au
-- premier dialogue) si pas encore installé.
local _gossipHookProbeFrame = CreateFrame("Frame")
_gossipHookProbeFrame:RegisterEvent("GOSSIP_SHOW")
_gossipHookProbeFrame:RegisterEvent("QUEST_DETAIL")
_gossipHookProbeFrame:SetScript("OnEvent", function()
  if not _dialogueCloseHookInstalled then
    -- Petit délai pour laisser DialogueUI Show() son frame avant le scan
    C_Timer.After(0.1, _tryHookDialogueUIClose)
  end
end)

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
-- Hook secondaire sur CinematicFrame_CancelCinematic pour capturer les SCÈNES
-- (IsInCinematicScene → CancelScene), car celles-ci ne passent PAS par StopCinematic.
-- Pour les vraies cinématiques (isRealCinematic = true), StopCinematic est
-- appelé en interne → déjà capturé par le hook StopCinematic → on évite le
-- double broadcast en retournant immédiatement.
if CinematicFrame_CancelCinematic then
  hooksecurefunc("CinematicFrame_CancelCinematic", function()
    TM.DebugPrint("[CinematicHook] CinematicFrame_CancelCinematic isLeader=", tostring(_isLeader()),
      "isRealCinematic=", tostring(CinematicFrame and CinematicFrame.isRealCinematic))
    if not (TM.db and TM.db.autoSkipCinematic ~= false) then return end
    if not _isLeader() then return end
    -- Vraie cinématique moteur → StopCinematic hook s'en charge → ne pas doubler.
    if CinematicFrame and CinematicFrame.isRealCinematic then return end
    -- Scène cinématique ou autre → broadcaster.
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
-- Cas 1 : proposition LFG (popup donjon prêt) — AcceptProposal → géré par autoEnterDungeon
-- Guarded: AcceptProposal may not exist in all TWW builds; a nil hook would Lua-error
-- and prevent all subsequent code (including delveDetectFrame) from loading.
if AcceptProposal then
  hooksecurefunc("AcceptProposal", function()
    TM.DebugPrint("AcceptProposal déclenché (leader=", tostring(_isLeader()), ")")
    if not (TM.db and TM.db.autoEnterDungeon ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastInstanceEnter then TM.BroadcastInstanceEnter("lfg") end
  end)
else
  TM.DebugPrint("AcceptProposal absent de l'API TWW — hook LFG désactivé")
end

-- Cas 1b : confirmation de rôle LFG (popup « Confirmez votre rôle ») — AcceptRoleCheck → autoEnterDungeon
if AcceptRoleCheck then
  hooksecurefunc("AcceptRoleCheck", function()
    TM.DebugPrint("AcceptRoleCheck déclenché (leader=", tostring(_isLeader()), ")")
    if not (TM.db and TM.db.autoEnterDungeon ~= false) then return end
    if not _isLeader() then return end
    if TM.BroadcastRoleCheck then TM.BroadcastRoleCheck() end
  end)
else
  TM.DebugPrint("AcceptRoleCheck absent de l'API TWW — hook désactivé")
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

-- Côté membre : auto-accepter LFG_PROPOSAL_SHOW directement si autoEnterDungeon activé.
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
  if not (TM.db and TM.db.autoEnterDungeon ~= false) then return end
  if _isLeader() then return end
  TM.AcceptInstanceProposal()
end)

-- Côté membre : mémoriser que LFG_ROLE_CHECK_SHOW s'est déclenché localement.
-- Si ROLECHECK du leader arrive APRÈS → accepter immédiatement.
-- Si ROLECHECK du leader arrive AVANT → il l'aura mis en pendingRoleCheck et lancé StartRoleCheckPoll.
local lfgRoleCheckFrame = CreateFrame("Frame")
lfgRoleCheckFrame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
lfgRoleCheckFrame:SetScript("OnEvent", function()
  if not (TM.db and TM.db.autoEnterDungeon ~= false) then return end
  TM.DebugPrint("[RoleCheck] LFG_ROLE_CHECK_SHOW reçu (pendingRoleCheck=", tostring(TM.pendingRoleCheck), ")")
  if TM.pendingRoleCheck then
    -- Le broadcast du leader est déjà arrivé → accepter immédiatement
    TM.pendingRoleCheck = false
    TM.AcceptRoleCheckForDungeon()
    TM.DebugPrint("[RoleCheck] Acceptation immédiate (pendingRoleCheck était true)")
  else
    -- Le broadcast n'est pas encore arrivé → mémoriser la fenêtre de fraîcheur (15s)
    TM._roleCheckReadyUntil = GetTime() + 15
    TM.DebugPrint("[RoleCheck] roleCheckReadyUntil mémorisé (+15s)")
  end
end)

-- ─── Auto-mount : leader invoque une monture → broadcast catégorie ─────
-- On détecte tout cast de sort de monture du joueur via UNIT_SPELLCAST_SUCCEEDED,
-- puis on résout spellID → mountID via C_MountJournal.GetMountFromSpell.
-- Cela couvre tous les chemins (clic dans le journal, /cast, macro, mount aléatoire,
-- raccourci par défaut Blizzard) car tous finissent en cast d'un sort de mount côté serveur.
local _lastMountBroadcast = 0
local mountCastFrame = CreateFrame("Frame")
mountCastFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
mountCastFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
  if not spellID then return end
  if not (TM.db and TM.db.autoMount ~= false) then return end
  if not _isLeader() then return end
  if not (C_MountJournal and C_MountJournal.GetMountFromSpell) then return end
  local mountID = C_MountJournal.GetMountFromSpell(spellID)
  if not mountID then return end
  -- Anti-spam : éviter un re-broadcast si on a déjà émis pour cette monture il y a < 5s.
  local now = GetTime()
  if (now - _lastMountBroadcast) < 5 then
    TM.DebugPrint("[MountHook] anti-spam, skip (mountID=", mountID, ")")
    return
  end
  _lastMountBroadcast = now
  local category = TM.GetMountCategoryFromMountID(mountID) or "ground"
  TM.DebugPrint("[MountHook] leader cast mount spellID=", spellID,
    "mountID=", mountID, "category=", category)
  if TM.BroadcastMount then TM.BroadcastMount(category) end
end)


-- ─── Hearthstone sync : leader utilise une pierre de foyer -> broadcast ───
local _lastHearthBroadcast = 0
local hearthKeywords = { "Hearthstone", "Pierre de foyer", "Pierre de foyer :", "Hearth" }
local hearthCastFrame = CreateFrame("Frame")
hearthCastFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
hearthCastFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
  if not spellID then return end
  if not (TM.db and TM.db.autoHearth ~= false) then return end
  if not _isLeader() then return end
  local sname = GetSpellInfo(spellID)
  if not sname then return end
  for _, kw in ipairs(hearthKeywords) do
    if sname:find(kw) then
      local now = GetTime()
      if (now - _lastHearthBroadcast) < 5 then
        TM.DebugPrint("[HearthHook] anti-spam, skip (spell=", sname, ")")
        return
      end
      _lastHearthBroadcast = now
      if TM.BroadcastHearth then TM.BroadcastHearth() end
      TM.DebugPrint("[HearthHook] leader cast hearth spell=", sname)
      return
    end
  end
end)
