-- TeamManager: Sync — broadcast and receive addon messages (team sync + XP/stats)

-- Broadcast team data via the fixed INVITE_PREFIX so all members receive it
-- regardless of their configured sync prefix.
function TM.BroadcastTeamInvite(teamName)
  if not IsInGroup() then return end
  local t = TM.db.teams[teamName]
  if not t then return end
  local members = table.concat(t.members or {}, ",")
  local payload = string.format("TEAM_INVITE|%s|%s|%s|%s",
    teamName, t.leader or "", members, TM.SYNC_PREFIX)
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.INVITE_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastTeamInvite ->", channel, payload)
end

function TM.BroadcastTeamSync(teamName)
  if not IsInGroup() then return end
  if not teamName then return end
  local t = TM.db.teams[teamName]
  if not t then return end
  local members = table.concat(t.members or {}, ",")
  local payload = string.format("TEAM|%s|%s|%s", teamName, t.leader or "", members)
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("Broadcast sync ->", channel, payload)
end

function TM.BroadcastXPSync()
  local lvl    = UnitLevel("player") or 0
  local xp     = UnitXP("player") or 0
  local xpMax  = UnitXPMax("player") or 1
  local pct    = (xpMax > 0) and math.floor(xp / xpMax * 1000 + 0.5) / 10 or 0
  local name   = UnitName("player") or ""
  local _, classFile = UnitClass("player"); classFile = classFile or ""
  local _, raceFile  = UnitRace("player");  raceFile  = raceFile  or ""
  local faction = UnitFactionGroup("player") or ""
  local specName = ""
  if GetSpecialization and GetSpecializationInfo then
    local specIdx = GetSpecialization()
    if specIdx then specName = select(2, GetSpecializationInfo(specIdx)) or "" end
  end
  local sex = UnitSex("player") or 2
  -- cache locally
  TM.memberXPCache[name] = {
    level = lvl, xpPct = pct, classFile = classFile,
    raceFile = raceFile, faction = faction, specName = specName, sex = sex,
  }
  if TM.db then
    if not TM.db.memberCache then TM.db.memberCache = {} end
    TM.db.memberCache[name] = TM.memberXPCache[name]
  end
  if not IsInGroup() then return end
  local payload = string.format("XP|%s|%d|%.1f|%s|%s|%s|%s|%d",
    name, lvl, pct, classFile, raceFile, faction, specName, sex)
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
end

-- Broadcast follow or assist state to group members
-- stateType: "follow" or "assist", target: short name (or nil to clear)
function TM.BroadcastMemberState(stateType, target)
  -- Update own cache immediately
  local me = UnitName("player")
  TM.memberStateCache[me] = TM.memberStateCache[me] or {}
  TM.memberStateCache[me][stateType] = (target and target ~= "") and target or nil
  -- Refresh floating panel
  local ui = TM.ui
  if ui and ui.floatingMemberList and ui.floatingMemberList:IsShown() then
    TM.RefreshFloatingMemberList()
  end
  if not IsInGroup() then return end
  local payload = "STATE|" .. stateType .. "|" .. (target or "")
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastMemberState:", stateType, "->", tostring(target))
end

-- Broadcast quest accept to group members (leader → members)
-- questID: the WoW questID that was accepted
function TM.BroadcastQuestAccept(questID)
  if not IsInGroup() then return end
  local payload = "QACCEPT|" .. (questID or 0)
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastQuestAccept questID=", questID)
end

-- Broadcast quest validation (turn-in) to group members (leader → members)
-- questID: the WoW questID being completed/turned-in
function TM.BroadcastQuestValidate(questID)
  if not IsInGroup() then return end
  local payload = "QVALIDATE|" .. (questID or 0)
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastQuestValidate questID=", questID)
end

-- Broadcast quest reward selection to group members (leader → members)
-- questID: the WoW questID, choice: reward item index (0 = no choice reward)
function TM.BroadcastQuestReward(questID, choice)
  if not IsInGroup() then return end
  local payload = "QREWARD|" .. (questID or 0) .. "|" .. (choice or 0)
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastQuestReward questID=", questID, "choice=", choice)
end

-- Broadcast gossip option selection to group members (leader → membres)
-- Payload : GOSSIP|gossipOptionID|orderIndex
--   * gossipOptionID : ID server-stable (chemin nominal)
--   * orderIndex     : index passé à SelectOptionByIndex (fallback si gossipOptionID inconnu).
-- Cas vu en pratique avec DialogueUI : pour certaines options de type "hint" / story,
-- DialogueUI passe `data.orderIndex or 0` à SelectOptionByIndex, et l'option correspondante
-- n'a pas nécessairement de gossipOptionID résolvable côté client. On broadcast donc les
-- deux et le membre essaie SelectOption(gossipOptionID), puis SelectOptionByIndex(orderIndex).
function TM.BroadcastGossipSelect(gossipOptionID, orderIndex)
  if not IsInGroup() then return end
  -- Garde-fou : si on n'a vraiment rien, on n'envoie rien (sinon on spammerait "|0|0")
  if (not gossipOptionID or gossipOptionID == 0) and not orderIndex then return end
  local payload = string.format("GOSSIP|%s|%s", tostring(gossipOptionID or 0), tostring(orderIndex or ""))
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastGossipSelect gossipOptionID=", gossipOptionID, "orderIndex=", orderIndex)
end

-- Broadcast "fermer le panel de dialogue/quête" (leader → membres)
-- Cas typique : avec DialogueUI, le serveur a déjà émis GOSSIP_CLOSED mais l'UI
-- locale du membre garde la dernière phrase du PNJ ouverte. Quand le leader ferme
-- son DialogueUI (Esc / clic Au revoir), aucun event serveur n'est émis → on broadcast
-- explicitement un signal CLOSEUI pour fermer le frame du membre.
function TM.BroadcastDialogClose()
  if not IsInGroup() then return end
  local payload = "CLOSEUI|1"
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastDialogClose envoyé")
end

-- Recherche le frame principal de DialogueUI dans la liste des frames du jeu.
-- DialogueUI ne s'expose pas dans _G : on identifie son frame par la signature
-- de son mixin (méthodes uniques HideUI + AcquireAcceptButton + SetSelectedGossipIndex).
-- Résultat caché dans TM._dialogueUIFrame (revalidé si invalide).
function TM.FindDialogueUIFrame()
  local cached = TM._dialogueUIFrame
  if cached and cached.HideUI and cached.AcquireAcceptButton then
    return cached
  end
  if not EnumerateFrames then return nil end
  local f = EnumerateFrames()
  while f do
    -- Test cheap : trois méthodes uniques du mixin DUIDialogBaseMixin (cf. DialogueUI.lua)
    if f.HideUI and f.AcquireAcceptButton and f.SetSelectedGossipIndex then
      TM._dialogueUIFrame = f
      return f
    end
    f = EnumerateFrames(f)
  end
  return nil
end

-- Broadcast d'une quête DISPONIBLE choisie depuis un PNJ gossip (leader → membres)
-- C'est le chemin de l'icône "?" jaune dans le GossipFrame :
-- l'UI Blizzard appelle C_GossipInfo.SelectAvailableQuest(questID), ce qui déclenche
-- ensuite QUEST_DETAIL (puis l'auto-accept standard via QACCEPT).
function TM.BroadcastGossipQuestAvailable(questID)
  if not IsInGroup() then return end
  if not questID or questID == 0 then return end
  local payload = "GOSSIPQAVAIL|" .. questID
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastGossipQuestAvailable questID=", questID)
end

-- Broadcast d'une quête ACTIVE (à rendre) choisie depuis un PNJ gossip (leader → membres)
-- C'est le chemin de l'icône "?" dorée : C_GossipInfo.SelectActiveQuest(questID),
-- qui ouvre QUEST_PROGRESS / QUEST_COMPLETE (le flow QVALIDATE/QREWARD prend ensuite le relais).
function TM.BroadcastGossipQuestActive(questID)
  if not IsInGroup() then return end
  if not questID or questID == 0 then return end
  local payload = "GOSSIPQACTIVE|" .. questID
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastGossipQuestActive questID=", questID)
end

-- Broadcast cinematic skip to group members (leader → members)
-- kind: "cinematic" (moteur in-game) ou "movie" (vidéo pré-rendue)
function TM.BroadcastCinematicSkip(kind)
  if not IsInGroup() then return end
  local payload = "CINESKIP|" .. (kind or "cinematic")
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastCinematicSkip kind=", kind)
end

-- Applique l'auto-skip côté membre. Si la cinématique n'est pas encore
-- affichée (latence / chargement), on arme un "pending skip" consommé par
-- les events CINEMATIC_START / PLAY_MOVIE.
-- allowPending : true → arme le pending si rien n'est visible
TM._pendingCineSkip = TM._pendingCineSkip or { kind = nil, expires = 0 }

local function _dismissCinematicConfirm()
  -- Ferme la popup "Êtes-vous sûr de vouloir passer la cinématique ?"
  -- qui peut traîner sur le membre s'il a appuyé sur ESC.
  if StaticPopup_Hide then
    StaticPopup_Hide("CONFIRM_STOP_CINEMATIC")
  end
  -- closeDialog du CinematicFrame (cas moteur) ou MovieFrame (vidéo)
  if CinematicFrame and CinematicFrame.closeDialog and CinematicFrame.closeDialog:IsShown() then
    CinematicFrame.closeDialog:Hide()
  end
  if MovieFrame and MovieFrame.CloseDialog and MovieFrame.CloseDialog:IsShown() then
    MovieFrame.CloseDialog:Hide()
  end
end

function TM.ApplyCinematicSkip(kind, allowPending)
  kind = kind or "cinematic"
  local done = false
  if kind == "movie" then
    if MovieFrame and MovieFrame:IsShown() and MovieFrame.FinishMovie then
      _dismissCinematicConfirm()
      MovieFrame:FinishMovie()
      done = true
      TM.DebugPrint("Auto-skip vid\195\169o (membre)")
    end
  else
    if CinematicFrame and CinematicFrame:IsShown() and StopCinematic then
      _dismissCinematicConfirm()
      StopCinematic()
      done = true
      TM.DebugPrint("Auto-skip cin\195\169matique (membre)")
    end
  end
  if not done and allowPending then
    -- Cinématique pas encore affichée : on arme un pending skip de 15s.
    TM._pendingCineSkip.kind = kind
    TM._pendingCineSkip.expires = GetTime() + 15
    TM.DebugPrint("CINESKIP en attente (kind=", kind, ", TTL=15s)")
    -- Petit retry court terme pour couvrir le cas où le frame s'affiche
    -- juste après la réception (StopCinematic peut ne pas être prêt
    -- pendant la première frame).
    if C_Timer and C_Timer.After then
      for _, delay in ipairs({ 0.2, 0.5, 1.0, 2.0 }) do
        C_Timer.After(delay, function()
          if TM._pendingCineSkip.kind and GetTime() < TM._pendingCineSkip.expires then
            TM.ApplyCinematicSkip(TM._pendingCineSkip.kind, false)
          end
        end)
      end
    end
  elseif done then
    TM._pendingCineSkip.kind = nil
    TM._pendingCineSkip.expires = 0
  end
  return done
end

-- Event frame pour consommer le pending skip dès que la cinématique démarre
local _cineSkipEventFrame = CreateFrame("Frame")
_cineSkipEventFrame:RegisterEvent("CINEMATIC_START")
_cineSkipEventFrame:RegisterEvent("PLAY_MOVIE")
_cineSkipEventFrame:RegisterEvent("CINEMATIC_STOP")
_cineSkipEventFrame:RegisterEvent("STOP_MOVIE")
_cineSkipEventFrame:SetScript("OnEvent", function(_, event)
  if event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
    -- Nettoyage : si une popup de confirmation traîne, on la ferme.
    _dismissCinematicConfirm()
    return
  end
  if not (TM.db and TM.db.autoSkipCinematic ~= false) then return end
  local pending = TM._pendingCineSkip
  if not pending or not pending.kind then return end
  if GetTime() > pending.expires then
    pending.kind = nil
    pending.expires = 0
    return
  end
  -- Coercion de cohérence : l'event nous dit le vrai type qui démarre
  local realKind = (event == "PLAY_MOVIE") and "movie" or "cinematic"
  -- Petit délai pour laisser le frame s'afficher avant StopCinematic
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, function()
      TM.ApplyCinematicSkip(realKind, false)
    end)
    C_Timer.After(0.3, function()
      TM.ApplyCinematicSkip(realKind, false)
    end)
  else
    TM.ApplyCinematicSkip(realKind, false)
  end
end)

-- Broadcast taxi node selection to group members (leader → members)
-- IMPORTANT : on broadcast le NOM de la destination (et pas l'index), car l'index
-- du noeud taxi diffère d'un personnage à l'autre selon les points de vol découverts.
-- Chaque membre retrouve l'index local correspondant au nom reçu.
function TM.BroadcastTaxiNode(nodeIndex)
  if not IsInGroup() then return end
  local nodeName = (nodeIndex and TaxiNodeName) and TaxiNodeName(nodeIndex) or ""
  if nodeName == "" then
    TM.DebugPrint("BroadcastTaxiNode : nom introuvable pour index=", nodeIndex)
    return
  end
  local payload = "TAXI|" .. nodeName
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastTaxiNode name=", nodeName, "(localIndex=", nodeIndex, ")")
end

-- Broadcast instance enter confirmation to group members (leader → members)
-- kind: "lfg" (proposition LFG) ou "portal" (portail monde)
function TM.BroadcastInstanceEnter(kind)
  if not IsInGroup() then return end
  local payload = "INSTENTER|" .. (kind or "lfg")
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastInstanceEnter kind=", kind)
end

-- Broadcast delve direct enter to group members (leader → members)
-- tier: le tier sélectionné par le leader via C_DelvesUI.SelectDelveEntranceTier
function TM.BroadcastDelveEnter(tier)
  if not IsInGroup() then return end
  local payload = "DELVEENTER|" .. (tier or 1)
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastDelveEnter tier=", tier)
end

-- Broadcast delve exit confirmation to group members (leader → members)
function TM.BroadcastDelveExit()
  if not IsInGroup() then return end
  local payload = "DELVEEXIT|1"
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastDelveExit envoyé")
end

-- ─── Auto-mount : catégorisation des montures ─────────────────────────
-- Mapping mountTypeID (renvoyé par C_MountJournal.GetMountInfoExtraByID) → catégorie
-- logique. Les valeurs proviennent de l'API publique et de l'observation du
-- MountJournal Blizzard. Les IDs absents tombent en "ground" par défaut.
TM.MOUNT_TYPE_CATEGORY = {
  -- Ground / surface
  [230] = "ground",   -- Mount monté terrestre standard
  [269] = "ground",   -- Water Strider (marche sur l'eau, traité comme sol)
  [284] = "ground",   -- Chauffeured Chopper / véhicules monoplaces
  [407] = "ground",   -- Drustridable / autres terrestres récents
  -- Aquatique (nage en profondeur)
  [231] = "aquatic",  -- Riding Turtle / Sea Turtle
  [232] = "aquatic",  -- Vashj'ir Seahorse
  [254] = "aquatic",  -- Subdued Seahorse
  [412] = "aquatic",  -- Mounts aquatiques de surface
  -- Volant classique (vol "à l'ancienne")
  [247] = "flying",   -- Red Flying Cloud
  [248] = "flying",   -- Mount volant générique
  -- Skyriding / Dragonriding (TWW : la plupart des mounts volants modernes)
  [402] = "skyriding",
  [424] = "skyriding",
  [437] = "skyriding",
  [463] = "skyriding",
  [464] = "skyriding",
  [466] = "skyriding",
}

function TM.GetMountCategoryFromTypeID(mountTypeID)
  if not mountTypeID then return "ground" end
  return TM.MOUNT_TYPE_CATEGORY[mountTypeID] or "ground"
end

function TM.GetMountCategoryFromMountID(mountID)
  if not mountID or not (C_MountJournal and C_MountJournal.GetMountInfoExtraByID) then
    return nil
  end
  local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
  return TM.GetMountCategoryFromTypeID(mountTypeID)
end

-- Broadcast l'invocation de monture du leader. category: "ground"/"flying"/"aquatic"/"skyriding"
function TM.BroadcastMount(category)
  if not IsInGroup() then return end
  if not category or category == "" then return end
  local payload = "MOUNT|" .. category
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastMount category=", category)
end

-- Broadcast : leader utilise une pierre de foyer
function TM.BroadcastHearth()
  if not IsInGroup() then return end
  local payload = "HEARTH|1"
  local channel = IsInRaid() and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(TM.SYNC_PREFIX, payload, channel)
  end
  TM.DebugPrint("BroadcastHearth sent")
end

-- Tente d'utiliser la pierre de foyer locale du joueur : recherche par nom localisé
function TM.TryUseHearth()
  if InCombatLockdown and InCombatLockdown() then return false end
  if IsMounted and IsMounted() then return false end
  local candidates = { "Hearthstone", "Pierre de foyer", "Pierre de foyer :" }
  -- Essayer UseItemByName pour des noms connus
  for _, nm in ipairs(candidates) do
    if GetItemCount and GetItemCount(nm) and GetItemCount(nm) > 0 then
      UseItemByName(nm)
      TM.DebugPrint("TryUseHearth: UseItemByName ->", nm)
      return true
    end
  end
  -- Parcourir les sacs pour détecter un item dont le nom contient hearth/foyer
  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag)
    for slot = 1, slots do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local iname = GetItemInfo(link)
        if iname and (iname:find("Hearthstone") or iname:find("Pierre de foyer") or iname:find("Foyer")) then
          UseContainerItem(bag, slot)
          TM.DebugPrint("TryUseHearth: UseContainerItem ->", iname)
          return true
        end
      end
    end
  end
  TM.DebugPrint("TryUseHearth: aucune pierre trouvée")
  return false
end

-- Sélectionne aléatoirement une monture favorite du joueur dans la catégorie demandée.
-- Renvoie un mountID utilisable, ou nil si rien de pertinent.
function TM.PickFavoriteMountByCategory(category)
  if not (C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID) then
    return nil
  end
  local ids = C_MountJournal.GetMountIDs()
  if not ids then return nil end

  local matches, fallbackUsable = {}, {}
  for _, mid in ipairs(ids) do
    local name, _, _, _, isUsable, _, isFavorite, _, _, shouldHideOnChar, isCollected, mountID =
      C_MountJournal.GetMountInfoByID(mid)
    mountID = mountID or mid
    if isCollected and isFavorite and isUsable and not shouldHideOnChar then
      local cat = TM.GetMountCategoryFromMountID(mountID)
      if cat == category then
        matches[#matches + 1] = mountID
      end
      fallbackUsable[#fallbackUsable + 1] = mountID
      -- name kept for debug only
      if false then TM.DebugPrint("[mount] fav usable", name, cat) end
    end
  end

  if #matches > 0 then
    return matches[math.random(#matches)], "match"
  end
  -- Compatibilité skyriding ↔ flying : si aucun favori exact, accepter l'autre côté volant.
  if category == "flying" or category == "skyriding" then
    local altCat = (category == "flying") and "skyriding" or "flying"
    local altMatches = {}
    for _, mid in ipairs(fallbackUsable) do
      if TM.GetMountCategoryFromMountID(mid) == altCat then
        altMatches[#altMatches + 1] = mid
      end
    end
    if #altMatches > 0 then return altMatches[math.random(#altMatches)], "alt-fly" end
  end
  -- Dernier filet : un favori utilisable quelconque.
  if #fallbackUsable > 0 then
    return fallbackUsable[math.random(#fallbackUsable)], "any-fav"
  end
  return nil, "none"
end

-- Trigger XP broadcast on relevant events
local xpSyncFrame = CreateFrame("Frame")
xpSyncFrame:RegisterEvent("PLAYER_XP_UPDATE")
xpSyncFrame:RegisterEvent("PLAYER_LEVEL_UP")
xpSyncFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
xpSyncFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
xpSyncFrame:SetScript("OnEvent", function(self, event)
  TM.BroadcastXPSync()
  if event == "GROUP_ROSTER_UPDATE" and IsInGroup() then
    -- Le leader re-diffuse les données de sa team sélectionnée pour mettre à jour
    -- tous les persos groupés (y compris les nouveaux membres qui viennent de rejoindre).
    local teamToBroadcast = TM.selectedTeam
    if teamToBroadcast and TM.db and TM.db.teams then
      local t = TM.db.teams[teamToBroadcast]
      if t and t.leader then
        local leaderShort = t.leader:match("^(.-)%-") or t.leader
        if leaderShort == UnitName("player") then
          C_Timer.After(0.5, function()
            TM.BroadcastTeamSync(teamToBroadcast)
            TM.DebugPrint("GROUP_ROSTER_UPDATE: sync team ->", teamToBroadcast)
          end)
        end
      end
    end
    -- Re-diffuse aussi l'invite de team si une invite est en attente
    if TM.pendingInviteTeam then
      local pendingTeam = TM.pendingInviteTeam
      local t = TM.db.teams[pendingTeam]
      if t and t.leader then
        local leaderShort = t.leader:match("^(.-)%-") or t.leader
        if leaderShort == UnitName("player") then
          C_Timer.After(0.5, function()
            TM.BroadcastTeamInvite(pendingTeam)
            TM.DebugPrint("GROUP_ROSTER_UPDATE: re-broadcast TEAM_INVITE pour", pendingTeam)
          end)
        end
      end
    end
  end
end)

-- ─── Handler GOSSIP_SHOW : mémoriser que le serveur a un gossip actif ────
-- DialogueUI / Immersion masquent GossipFrame Blizzard, donc on ne peut pas se
-- baser sur sa visibilité côté receveur. On mémorise la fenêtre de fraîcheur
-- (~10s) pendant laquelle C_GossipInfo.SelectOptionByIndex/SelectOption est
-- accepté par le serveur, indépendamment de l'UI affichée.
local gossipShowFrame = CreateFrame("Frame")
gossipShowFrame:RegisterEvent("GOSSIP_SHOW")
gossipShowFrame:RegisterEvent("GOSSIP_CLOSED")
gossipShowFrame:SetScript("OnEvent", function(self, event)
  if event == "GOSSIP_SHOW" then
    TM.gossipReadyAt = GetTime()
    TM.DebugPrint("[GossipEvent] GOSSIP_SHOW (gossipReadyAt mémorisé)")
  elseif event == "GOSSIP_CLOSED" then
    TM.DebugPrint("[GossipEvent] GOSSIP_CLOSED")
  end
end)

-- ─── Handlers événements quête côté membre ────────────────────────────────
-- QUEST_DETAIL          → mémorise questID offert ; si QACCEPT pending → RequestLoadQuestByID
-- QUEST_DATA_LOAD_RESULT → si questID correspond au pending QACCEPT → AcceptQuest()
-- QUEST_PROGRESS        → mémorise questID de progression ; si QVALIDATE pending → CompleteQuest()
-- QUEST_COMPLETE        → si QREWARD pending correspond → GetQuestReward(choice)
-- Chaque message peut arriver AVANT ou APRÈS l'event WoW côté membre ; les deux sens sont couverts.
local questDetailAutoFrame = CreateFrame("Frame")
questDetailAutoFrame:RegisterEvent("QUEST_DETAIL")
questDetailAutoFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
questDetailAutoFrame:RegisterEvent("QUEST_PROGRESS")
questDetailAutoFrame:RegisterEvent("QUEST_COMPLETE")
questDetailAutoFrame:RegisterEvent("QUEST_FINISHED")
questDetailAutoFrame:SetScript("OnEvent", function(self, event, arg1)
  -- ── QUEST_DETAIL : quête proposée ──────────────────────────────────────
  if event == "QUEST_DETAIL" then
    local questID = GetQuestID and GetQuestID() or 0
    TM.DebugPrint("[QuestEvent] QUEST_DETAIL questID=", questID, "pendingAccept=", tostring(TM.pendingAutoAcceptQuestID))
    if questID == 0 then return end
    TM.pendingQuestDetailID = questID
    if TM.pendingAutoAcceptQuestID and
       (TM.pendingAutoAcceptQuestID == 0 or TM.pendingAutoAcceptQuestID == questID) then
      if not (TM.db and TM.db.autoAcceptQuest ~= false) then
        TM.pendingAutoAcceptQuestID = nil
        return
      end
      TM.pendingAutoAcceptQuestID = questID
      if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        C_QuestLog.RequestLoadQuestByID(questID)
        TM.DebugPrint("Auto-accept quête: RequestLoadQuestByID (QUEST_DETAIL+pending) questID=", questID)
      else
        C_Timer.After(0, function() AcceptQuest() end)
        TM.pendingAutoAcceptQuestID = nil
        TM.DebugPrint("Auto-accept quête (fallback direct) questID=", questID)
      end
    end

  -- ── QUEST_DATA_LOAD_RESULT : données de quête chargées → accepter ──────
  elseif event == "QUEST_DATA_LOAD_RESULT" then
    local questID = arg1
    if questID and TM.pendingAutoAcceptQuestID == questID then
      TM.pendingAutoAcceptQuestID = nil
      if not (TM.db and TM.db.autoAcceptQuest ~= false) then return end
      AcceptQuest()
      if QuestFrame and QuestFrame:IsShown() then QuestFrame:Hide() end
      TM.DebugPrint("Auto-accept quête depuis leader (QUEST_DATA_LOAD_RESULT) questID=", questID)
    end

  -- ── QUEST_PROGRESS : fenêtre de progression prête → CompleteQuest si pending
  elseif event == "QUEST_PROGRESS" then
    local questID = GetQuestID and GetQuestID() or 0
    TM.DebugPrint("[QuestEvent] QUEST_PROGRESS questID=", questID, "pendingValidate=", tostring(TM.pendingAutoValidateQuestID), "completable=", tostring(IsQuestCompletable and IsQuestCompletable()))
    if questID == 0 then return end
    TM.pendingQuestProgressID = questID
    -- Mémorise un "flag de fraîcheur" : utile si DialogueUI ferme le panel après l'event
    -- mais que le serveur accepte encore CompleteQuest() pendant quelques secondes.
    TM.questProgressReadyAt = GetTime()
    TM.questProgressReadyID = questID
    if TM.pendingAutoValidateQuestID and
       (TM.pendingAutoValidateQuestID == 0 or TM.pendingAutoValidateQuestID == questID) then
      if not (TM.db and TM.db.autoValidateQuest ~= false) then
        TM.pendingAutoValidateQuestID = nil
        return
      end
      TM.pendingAutoValidateQuestID = nil
      C_Timer.After(0, function()
        if IsQuestCompletable() then
          CompleteQuest()
          TM.DebugPrint("Auto-CompleteQuest (QUEST_PROGRESS+pending) questID=", questID)
        else
          TM.DebugPrint("Auto-CompleteQuest: quête non completable questID=", questID)
        end
      end)
    end

  -- ── QUEST_COMPLETE : panel récompenses prêt → GetQuestReward si pending ─
  elseif event == "QUEST_COMPLETE" then
    TM.DebugPrint("[QuestEvent] QUEST_COMPLETE questID=", GetQuestID and GetQuestID() or 0, "pendingReward=", tostring(TM.pendingAutoRewardQuestID))
    -- Mémorise un "flag de fraîcheur" : DialogueUI cache immédiatement le QuestFrame
    -- Blizzard après cet event, donc rewardsReady redevient false. Mais le serveur
    -- accepte GetQuestReward() pendant ~10s. On enregistre questID + timestamp pour
    -- que le handler QREWARD (qui peut arriver après) puisse forcer l'appel.
    local questID = GetQuestID and GetQuestID() or 0
    if questID > 0 then
      TM.questCompleteReadyAt = GetTime()
      TM.questCompleteReadyID = questID
      TM.DebugPrint("QUEST_COMPLETE mémorisé questID=", questID)
    end

    -- ─── Broadcast LEADER → MEMBRES (path indépendant des hooks UI) ────
    -- DialogueUI capture CompleteQuest/GetQuestReward en upvalue local, donc nos
    -- hooksecurefunc("CompleteQuest") et les hooks de boutons sont bypassés.
    -- L'event serveur QUEST_COMPLETE, lui, fire toujours quand le panel récompense
    -- s'ouvre, peu importe l'UI utilisée. On l'utilise comme trigger fiable pour
    -- broadcaster QVALIDATE aux membres. Anti-doublon via TM._lastQValidateBroadcast.
    -- Côté membre, ce même event fire aussi quand il appelle CompleteQuest en réaction
    -- au QVALIDATE reçu — on évite le re-broadcast en filtrant : seul le leader broadcast.
    if questID > 0 and TM.selectedTeam then
      local team = TM.db and TM.db.teams and TM.db.teams[TM.selectedTeam]
      if team and team.leader then
        local leaderShort = team.leader:match("^(.-)%-") or team.leader
        local me = UnitName("player")
        if leaderShort == me and TM.db and TM.db.autoValidateQuest ~= false then
          TM._lastQValidateBroadcast = TM._lastQValidateBroadcast or {}
          local lastSent = TM._lastQValidateBroadcast[questID] or 0
          if (GetTime() - lastSent) > 5 then
            TM._lastQValidateBroadcast[questID] = GetTime()
            if TM.BroadcastQuestValidate then TM.BroadcastQuestValidate(questID) end
            TM.DebugPrint("Broadcast QVALIDATE (QUEST_COMPLETE event) questID=", questID)
          else
            TM.DebugPrint("QVALIDATE déjà broadcasté récemment pour questID=", questID, "skip")
          end
        end
      end
    end
    if TM.pendingAutoRewardQuestID then
      local pQuestID = TM.pendingAutoRewardQuestID
      local choice   = TM.pendingAutoRewardChoice or 0
      local localID  = questID
      if pQuestID == 0 or localID == pQuestID then
        TM.pendingAutoRewardQuestID = nil
        TM.pendingAutoRewardChoice  = nil
        if not (TM.db and TM.db.autoValidateQuest ~= false) then return end
        C_Timer.After(0, function()
          GetQuestReward(choice)
          TM.DebugPrint("Auto-GetQuestReward (QUEST_COMPLETE+pending) questID=", pQuestID, "choice=", choice)
        end)
      end
    end

  -- ── QUEST_FINISHED : fermeture de la fenêtre → nettoyer les pending ──
  elseif event == "QUEST_FINISHED" then
    TM.DebugPrint("[QuestEvent] QUEST_FINISHED")
    TM.pendingQuestDetailID    = nil
    TM.pendingQuestProgressID  = nil

  -- ── QUEST_DATA_LOAD_RESULT déjà géré au-dessus, log dispo dans le handler ──
  end
end)

-- Addon message receiver
local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("CHAT_MSG_ADDON")
syncFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
  if prefix ~= TM.SYNC_PREFIX then return end
  local me = UnitName("player")
  local senderShort = sender:match("^(.-)%-") or sender
  if senderShort == me then return end
  TM.DebugPrint("Sync reçu de", sender, "->", msg)
  local mtype = msg:match("^(%a+)|")
  if not mtype then return end

  -- State sync: STATE|follow|targetName  or  STATE|assist|targetName
  if mtype == "STATE" then
    local parts = {}
    for p in (msg .. "|"):gmatch("(.-)|") do parts[#parts + 1] = p end
    local sType   = parts[2] or ""
    local sTarget = parts[3] or ""
    if sType ~= "" and senderShort ~= "" then
      TM.memberStateCache[senderShort] = TM.memberStateCache[senderShort] or {}
      TM.memberStateCache[senderShort][sType] = (sTarget ~= "") and sTarget or nil
      TM.DebugPrint("STATE reçu de", senderShort, sType, "->", sTarget)
      local ui = TM.ui
      if ui and ui.floatingMemberList and ui.floatingMemberList:IsShown() then
        TM.RefreshFloatingMemberList()
      end
    end
    return
  end

  -- XP sync: XP|name|level|xpPct|classFile|raceFile|faction|specName|sex
  if mtype == "XP" then
    local parts = {}
    for p in (msg .. "|"):gmatch("(.-)|") do parts[#parts + 1] = p end
    local xpName = parts[2] or ""
    if xpName ~= "" then
      TM.memberXPCache[xpName] = {
        level    = tonumber(parts[3]) or 0,
        xpPct    = tonumber(parts[4]) or 0,
        classFile = parts[5] or "",
        raceFile  = parts[6] or "",
        faction   = parts[7] or "",
        specName  = parts[8] or "",
        sex       = tonumber(parts[9]) or 2,
      }
      if TM.db then
        if not TM.db.memberCache then TM.db.memberCache = {} end
        TM.db.memberCache[xpName] = TM.memberXPCache[xpName]
      end
      TM.DebugPrint("XP sync reçu:", xpName, "lvl=", parts[3], "xp=", (parts[4] or "").."%",
        "class=", parts[5], "spec=", parts[8])
      local ui = TM.ui
      if ui.floatingMemberList and ui.floatingMemberList:IsShown() then
        TM.RefreshFloatingMemberList()
      end
      if ui.frame and ui.frame:IsShown() and TM.selectedTeam then
        TM.SelectTeam(TM.selectedTeam, false)
      end
    end
    return
  end

  -- Quest auto-accept: QACCEPT|questID
  -- Le message addon peut arriver AVANT ou APRÈS QUEST_DETAIL côté membre.
  -- On utilise C_QuestLog.RequestLoadQuestByID + QUEST_DATA_LOAD_RESULT (comme EnhanceQoL),
  -- ce qui fonctionne même quand QuestFrameDetailPanel est déjà fermé.
  if mtype == "QACCEPT" then
    if TM.db and TM.db.autoAcceptQuest ~= false then
      local questID = tonumber(msg:match("^QACCEPT|(.+)$")) or 0
      -- Cas 1 : QUEST_DETAIL a déjà été déclenché (le membre a ouvert le PNJ avant la validation du leader)
      if TM.pendingQuestDetailID and (questID == 0 or TM.pendingQuestDetailID == questID) then
        local detailID = TM.pendingQuestDetailID
        TM.pendingAutoAcceptQuestID = detailID
        if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
          C_QuestLog.RequestLoadQuestByID(detailID)
          TM.DebugPrint("Auto-accept quête: RequestLoadQuestByID (QUEST_DETAIL précédent) questID=", detailID)
        else
          C_Timer.After(0, function() AcceptQuest() end)
          TM.pendingAutoAcceptQuestID = nil
          TM.DebugPrint("Auto-accept quête (fallback direct) questID=", detailID)
        end
      else
        -- Cas 2 : QUEST_DETAIL n'a pas encore eu lieu → stocker et attendre
        TM.pendingAutoAcceptQuestID = questID
        TM.DebugPrint("Auto-accept quête en attente QUEST_DETAIL questID=", questID)
        -- Timeout de sécurité
        C_Timer.After(30, function()
          if TM.pendingAutoAcceptQuestID == questID then
            TM.pendingAutoAcceptQuestID = nil
            TM.DebugPrint("Auto-accept quête: timeout questID=", questID)
          end
        end)
      end
    end
    return
  end

  -- Quest validate step 1: QVALIDATE|questID
  -- Le QVALIDATE peut arriver avant ou après QUEST_PROGRESS côté membre.
  -- Compat DialogueUI/Immersion : ces addons consomment souvent QUEST_PROGRESS sans le
  -- propager. On tente donc aussi un appel direct si IsQuestCompletable() retourne vrai
  -- (état serveur, indépendant de l'UI), ou si QUEST_PROGRESS a été vu récemment
  -- (TM.questProgressReadyAt) même si DialogueUI a depuis fermé le panel.
  if mtype == "QVALIDATE" then
    local progressReady = TM.questProgressReadyAt and (GetTime() - TM.questProgressReadyAt < 10)
    TM.DebugPrint("QVALIDATE reçu: autoValidateQuest=", tostring(TM.db and TM.db.autoValidateQuest), "pendingProgressID=", tostring(TM.pendingQuestProgressID), "IsQuestCompletable=", tostring(IsQuestCompletable and IsQuestCompletable()), "progressReady=", tostring(progressReady))
    if TM.db and TM.db.autoValidateQuest ~= false then
      local questID = tonumber(msg:match("^QVALIDATE|(.+)$")) or 0
      -- Cas 1 : QUEST_PROGRESS a déjà eu lieu (panel de progression actif)
      if TM.pendingQuestProgressID and (questID == 0 or TM.pendingQuestProgressID == questID) then
        TM.pendingAutoValidateQuestID = nil
        local resolvedID = TM.pendingQuestProgressID
        C_Timer.After(0, function()
          if IsQuestCompletable() then
            CompleteQuest()
            TM.DebugPrint("Auto-CompleteQuest questID=", resolvedID)
          else
            TM.DebugPrint("Auto-CompleteQuest: quête non completable questID=", resolvedID)
          end
        end)
      -- Cas 1bis : QUEST_PROGRESS vu récemment (DialogueUI a fermé le panel mais
      -- le serveur accepte encore CompleteQuest pendant quelques secondes)
      elseif progressReady and (questID == 0 or TM.questProgressReadyID == questID) then
        local resolvedID = TM.questProgressReadyID
        C_Timer.After(0, function()
          if IsQuestCompletable() then
            CompleteQuest()
            TM.DebugPrint("Auto-CompleteQuest (progressReady recent) questID=", resolvedID)
          else
            TM.DebugPrint("Auto-CompleteQuest: quête non completable (progressReady) questID=", resolvedID)
          end
        end)
      -- Cas 1ter : pas de QUEST_PROGRESS pending mais le serveur indique completable
      elseif IsQuestCompletable and IsQuestCompletable() then
        local localID = GetQuestID and GetQuestID() or 0
        if questID == 0 or localID == questID or localID == 0 then
          C_Timer.After(0, function()
            if IsQuestCompletable() then
              CompleteQuest()
              TM.DebugPrint("Auto-CompleteQuest (fallback IsQuestCompletable) questID=", questID)
            end
          end)
        end
      else
        -- Cas 2 : QUEST_PROGRESS pas encore déclenché → stocker et attendre
        TM.pendingAutoValidateQuestID = questID
        TM.DebugPrint("Auto-CompleteQuest en attente QUEST_PROGRESS questID=", questID)
        C_Timer.After(60, function()
          if TM.pendingAutoValidateQuestID == questID then
            TM.pendingAutoValidateQuestID = nil
            TM.DebugPrint("Auto-CompleteQuest: timeout questID=", questID)
          end
        end)
      end
    end
    return
  end

  -- Quest validate step 2: QREWARD|questID|choice
  -- Le QREWARD peut arriver avant que QUEST_COMPLETE soit traité côté membre.
  -- Compat DialogueUI/Immersion : ces addons cachent QuestFrameRewardPanel dès que
  -- QUEST_COMPLETE est émis, donc rewardsReady redevient false. On utilise le flag
  -- TM.questCompleteReadyAt (positionné dans le handler QUEST_COMPLETE) pour détecter
  -- que le serveur accepte encore GetQuestReward() même si l'UI Blizzard est cachée.
  if mtype == "QREWARD" then
    local rewardsReady = (GetNumQuestChoices and GetNumQuestChoices() or 0) > 0
                       or (GetNumQuestRewards and GetNumQuestRewards() or 0) > 0
                       or (QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown())
    local completeReady = TM.questCompleteReadyAt and (GetTime() - TM.questCompleteReadyAt < 10)
    TM.DebugPrint("QREWARD reçu: autoValidateQuest=", tostring(TM.db and TM.db.autoValidateQuest), "RewardPanel=", tostring(QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown()), "rewardsReady=", tostring(rewardsReady), "completeReady=", tostring(completeReady), "questCompleteReadyID=", tostring(TM.questCompleteReadyID))
    if TM.db and TM.db.autoValidateQuest ~= false then
      local parts = {}
      for p in (msg .. "|"):gmatch("(.-)|" ) do parts[#parts + 1] = p end
      local questID = tonumber(parts[2]) or 0
      local choice  = tonumber(parts[3]) or 0
      local localID = GetQuestID and GetQuestID() or 0
      -- Cas 1 : panel récompenses prêt (UI Blizzard, DialogueUI ou état serveur OK)
      if rewardsReady and (questID == 0 or localID == questID or localID == 0) then
        C_Timer.After(0, function()
          GetQuestReward(choice)
          TM.DebugPrint("Auto-GetQuestReward (immédiat/rewardsReady) questID=", questID, "choice=", choice)
        end)
      -- Cas 1bis : QUEST_COMPLETE vu récemment (DialogueUI a caché le panel mais
      -- le serveur accepte encore GetQuestReward pendant quelques secondes)
      elseif completeReady and (questID == 0 or TM.questCompleteReadyID == questID) then
        local resolvedID = TM.questCompleteReadyID
        C_Timer.After(0, function()
          GetQuestReward(choice)
          TM.DebugPrint("Auto-GetQuestReward (completeReady recent) questID=", resolvedID, "choice=", choice)
        end)
      else
        -- Cas 2 : QUEST_COMPLETE pas encore traité → stocker et attendre
        TM.pendingAutoRewardQuestID = questID
        TM.pendingAutoRewardChoice  = choice
        TM.DebugPrint("Auto-GetQuestReward en attente QUEST_COMPLETE questID=", questID)
        C_Timer.After(60, function()
          if TM.pendingAutoRewardQuestID == questID then
            TM.pendingAutoRewardQuestID = nil
            TM.pendingAutoRewardChoice  = nil
            TM.DebugPrint("Auto-GetQuestReward: timeout questID=", questID)
          end
        end)
      end
    end
    return
  end

  -- Gossip auto-select: GOSSIP|gossipOptionID|orderIndex
  -- gossipOptionID est server-stable ; orderIndex est aussi le même côté leader/membre
  -- (même PNJ → même liste d'options côté serveur).
  -- Côté receveur, on essaie en priorité SelectOption(gossipOptionID) ; si l'ID est 0
  -- (cas DialogueUI sur certaines options "hint"), on tombe sur SelectOptionByIndex(orderIndex).
  if mtype == "GOSSIP" then
    if TM.db and TM.db.autoSelectGossip ~= false then
      local gidStr, oidStr = msg:match("^GOSSIP|([^|]*)|?(.*)$")
      local gossipOptionID = tonumber(gidStr) or 0
      local orderIndex = tonumber(oidStr)  -- nil si vide / ancien format
      -- Compatibilité DialogueUI / Immersion : ne pas se baser sur GossipFrame:IsShown(),
      -- mais sur la disponibilité côté serveur (C_GossipInfo.GetOptions non vide)
      -- ou sur la fenêtre de fraîcheur (10s après GOSSIP_SHOW).
      local opts = (C_GossipInfo and C_GossipInfo.GetOptions) and C_GossipInfo.GetOptions() or nil
      local hasOpts = opts and #opts > 0
      local gossipFresh = TM.gossipReadyAt and (GetTime() - TM.gossipReadyAt < 10)
      local frameShown = GossipFrame and GossipFrame:IsShown()
      TM.DebugPrint("GOSSIP reçu: gossipOptionID=", gossipOptionID, "orderIndex=", orderIndex,
        "hasOpts=", tostring(hasOpts),
        "gossipFresh=", tostring(gossipFresh),
        "GossipFrame:IsShown=", tostring(frameShown))
      if (gossipOptionID > 0 or orderIndex) and (hasOpts or gossipFresh or frameShown) then
        local handled = false
        -- 1) Chemin nominal : SelectOption(gossipOptionID).
        if gossipOptionID > 0 and C_GossipInfo and C_GossipInfo.SelectOption then
          local optionExists = false
          if hasOpts then
            for _, info in ipairs(opts) do
              if info.gossipOptionID == gossipOptionID then optionExists = true; break end
            end
          end
          if optionExists or not hasOpts then
            C_GossipInfo.SelectOption(gossipOptionID, "", false)
            TM.DebugPrint("Auto-select dialogue PNJ via SelectOption, gossipOptionID=", gossipOptionID,
              "optionExists=", tostring(optionExists))
            handled = true
          end
        end
        -- 2) Fallback DialogueUI hint : SelectOptionByIndex(orderIndex) directement.
        --    L'orderIndex est server-stable et accepté par le serveur même quand
        --    GetOptions() ne renvoie pas l'option correspondante côté client.
        if not handled and orderIndex and C_GossipInfo and C_GossipInfo.SelectOptionByIndex then
          C_GossipInfo.SelectOptionByIndex(orderIndex)
          TM.DebugPrint("Auto-select dialogue PNJ via SelectOptionByIndex (fallback orderIndex), orderIndex=", orderIndex)
          handled = true
        end
        -- 3) Fallback positionnel via gossipOptionID (rare)
        if not handled and gossipOptionID > 0 and hasOpts and C_GossipInfo and C_GossipInfo.SelectOptionByIndex then
          for _, info in ipairs(opts) do
            if info.gossipOptionID == gossipOptionID then
              C_GossipInfo.SelectOptionByIndex(info.orderIndex or 0)
              TM.DebugPrint("Auto-select dialogue PNJ via SelectOptionByIndex (par gossipOptionID), orderIndex=",
                info.orderIndex)
              handled = true
              break
            end
          end
        end
        -- 4) Fallback classic : SelectGossipOption(index)
        if not handled and SelectGossipOption then
          local idx = orderIndex or gossipOptionID
          SelectGossipOption(idx)
          TM.DebugPrint("Auto-select dialogue PNJ (fallback classic), index=", idx)
          handled = true
        end
        if not handled then
          TM.DebugPrint("Auto-select dialogue PNJ : aucun chemin disponible (gossipOptionID=",
            gossipOptionID, "orderIndex=", orderIndex, ")")
        end
      else
        TM.DebugPrint("GOSSIP ignoré : aucun gossip actif côté membre (gossipOptionID=",
          gossipOptionID, "orderIndex=", orderIndex, ")")
      end
    end
    return
  end

  -- Gossip available quest auto-pick: GOSSIPQAVAIL|questID
  -- Le leader a cliqué sur une "quête disponible" (icône ? jaune) dans le GossipFrame.
  -- Côté membre on rejoue C_GossipInfo.SelectAvailableQuest(questID) qui ouvre le panneau
  -- QUEST_DETAIL ; l'auto-accept standard (QACCEPT/QUEST_DATA_LOAD_RESULT) prend le relais.
  if mtype == "GOSSIPQAVAIL" then
    if TM.db and TM.db.autoSelectGossip ~= false then
      local questID = tonumber(msg:match("^GOSSIPQAVAIL|(.+)$"))
      local opts = (C_GossipInfo and C_GossipInfo.GetAvailableQuests) and C_GossipInfo.GetAvailableQuests() or nil
      local hasOpts = opts and #opts > 0
      local gossipFresh = TM.gossipReadyAt and (GetTime() - TM.gossipReadyAt < 10)
      TM.DebugPrint("GOSSIPQAVAIL reçu questID=", questID,
        "hasOpts=", tostring(hasOpts), "gossipFresh=", tostring(gossipFresh))
      if questID and (hasOpts or gossipFresh) then
        local exists = false
        if hasOpts then
          for _, info in ipairs(opts) do
            if info.questID == questID then exists = true; break end
          end
        end
        if (exists or not hasOpts) and C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
          C_GossipInfo.SelectAvailableQuest(questID)
          TM.DebugPrint("Auto-pick quête disponible (gossip) questID=", questID,
            "exists=", tostring(exists))
        elseif SelectGossipAvailableQuest and hasOpts then
          for i, info in ipairs(opts) do
            if info.questID == questID then
              SelectGossipAvailableQuest(i)
              TM.DebugPrint("Auto-pick quête disponible (legacy index)", i)
              break
            end
          end
        else
          TM.DebugPrint("GOSSIPQAVAIL : API SelectAvailableQuest indisponible")
        end
      else
        TM.DebugPrint("GOSSIPQAVAIL ignoré : aucun gossip actif côté membre")
      end
    end
    return
  end

  -- Gossip active quest auto-pick (turn-in): GOSSIPQACTIVE|questID
  -- Le leader a cliqué sur une "quête active" (icône ? dorée). On rejoue
  -- C_GossipInfo.SelectActiveQuest(questID) → QUEST_PROGRESS/QUEST_COMPLETE ; les
  -- handlers QVALIDATE/QREWARD existants prennent ensuite le relais pour la remise.
  if mtype == "GOSSIPQACTIVE" then
    if TM.db and TM.db.autoSelectGossip ~= false then
      local questID = tonumber(msg:match("^GOSSIPQACTIVE|(.+)$"))
      local opts = (C_GossipInfo and C_GossipInfo.GetActiveQuests) and C_GossipInfo.GetActiveQuests() or nil
      local hasOpts = opts and #opts > 0
      local gossipFresh = TM.gossipReadyAt and (GetTime() - TM.gossipReadyAt < 10)
      TM.DebugPrint("GOSSIPQACTIVE reçu questID=", questID,
        "hasOpts=", tostring(hasOpts), "gossipFresh=", tostring(gossipFresh))
      if questID and (hasOpts or gossipFresh) then
        local exists = false
        if hasOpts then
          for _, info in ipairs(opts) do
            if info.questID == questID then exists = true; break end
          end
        end
        if (exists or not hasOpts) and C_GossipInfo and C_GossipInfo.SelectActiveQuest then
          C_GossipInfo.SelectActiveQuest(questID)
          TM.DebugPrint("Auto-pick quête active (gossip) questID=", questID,
            "exists=", tostring(exists))
        elseif SelectGossipActiveQuest and hasOpts then
          for i, info in ipairs(opts) do
            if info.questID == questID then
              SelectGossipActiveQuest(i)
              TM.DebugPrint("Auto-pick quête active (legacy index)", i)
              break
            end
          end
        else
          TM.DebugPrint("GOSSIPQACTIVE : API SelectActiveQuest indisponible")
        end
      else
        TM.DebugPrint("GOSSIPQACTIVE ignoré : aucun gossip actif côté membre")
      end
    end
    return
  end

  -- Close dialog UI: CLOSEUI|1
  -- Le leader vient de fermer son panneau de dialogue (Esc / clic Au revoir).
  -- Le serveur a déjà émis GOSSIP_CLOSED/QUEST_FINISHED, mais des UIs comme DialogueUI
  -- gardent leur frame visible pour afficher la dernière phrase du PNJ. On force la
  -- fermeture côté membre via plusieurs voies (DialogueUI, Blizzard Gossip/Quest).
  if mtype == "CLOSEUI" then
    if TM.db and TM.db.autoSelectGossip ~= false then
      TM.DebugPrint("CLOSEUI reçu : fermeture des panneaux de dialogue")
      -- 1) DialogueUI : on appelle HideUI() sur son frame s'il est trouvé et visible
      local duif = TM.FindDialogueUIFrame and TM.FindDialogueUIFrame()
      if duif and duif:IsShown() then
        if duif.HideUI then
          pcall(duif.HideUI, duif)
        else
          pcall(duif.Hide, duif)
        end
        TM.DebugPrint("CLOSEUI : DialogueUI:HideUI() appelé")
      end
      -- 2) UI Blizzard standard (filets de sécurité)
      if C_GossipInfo and C_GossipInfo.CloseGossip then C_GossipInfo.CloseGossip() end
      if CloseQuest then pcall(CloseQuest) end
      if HideUIPanel then
        if GossipFrame and GossipFrame:IsShown() then HideUIPanel(GossipFrame) end
        if QuestFrame and QuestFrame:IsShown() then HideUIPanel(QuestFrame) end
      end
    end
    return
  end

  -- Cinematic skip: CINESKIP|kind
  -- Receveur : utilise les BONNES APIs Blizzard
  --   * cinematic : StopCinematic() (CancelCinematic n'existe pas globalement)
  --   * movie     : MovieFrame:FinishMovie() (StopMovie global n'existe pas)
  -- IMPORTANT : le membre peut recevoir le CINESKIP AVANT que sa propre
  -- cinématique ne soit affichée (latence réseau / chargement de la cin.).
  -- Dans ce cas on arme un "pending skip" avec TTL, qui sera consommé dès que
  -- CINEMATIC_START / PLAY_MOVIE déclenche l'affichage côté membre.
  -- De plus, si une popup de confirmation (CONFIRM_STOP_CINEMATIC) reste
  -- affichée côté membre, on la ferme automatiquement.
  if mtype == "CINESKIP" then
    if TM.db and TM.db.autoSkipCinematic ~= false then
      local kind = msg:match("^CINESKIP|(.+)$") or "cinematic"
      TM.ApplyCinematicSkip(kind, true)
    end
    return
  end

  -- Taxi auto-select: TAXI|nodeName
  -- On reçoit le NOM de la destination (les index sont locaux à chaque joueur,
  -- ils dépendent des points de vol découverts). On itère NumTaxiNodes() pour
  -- retrouver l'index local qui correspond au nom reçu.
  if mtype == "TAXI" then
    if TM.db and TM.db.autoTaxi ~= false then
      local nodeName = msg:match("^TAXI|(.+)$")
      if nodeName and nodeName ~= "" then
        -- Vérifier que la carte de vol est ouverte (TaxiFrame retail/classic ou FlightMapFrame)
        local taxiOpen = (TaxiFrame and TaxiFrame:IsShown())
                      or (FlightMapFrame and FlightMapFrame:IsShown())
        if taxiOpen and NumTaxiNodes and TaxiNodeName and TakeTaxiNode then
          local found, foundIndex = false, nil
          for i = 1, NumTaxiNodes() do
            if TaxiNodeName(i) == nodeName then
              found, foundIndex = true, i
              break
            end
          end
          if found then
            TakeTaxiNode(foundIndex)
            TM.DebugPrint("Auto-taxi depuis leader: ", nodeName, "(localIndex=", foundIndex, ")")
          else
            TM.DebugPrint("Auto-taxi : destination non découverte localement: ", nodeName)
          end
        else
          TM.DebugPrint("Auto-taxi ignoré : aucune carte de vol ouverte (destination=", nodeName, ")")
        end
      end
    end
    return
  end

  -- Instance enter auto: INSTENTER|kind
  if mtype == "INSTENTER" then
    if TM.db and TM.db.autoEnterInstance ~= false then
      local kind = msg:match("^INSTENTER|(.+)$") or "lfg"

      if kind == "lfg" then
        -- Proposition LFG — activer le flag pending ET essai immédiat
        TM.pendingInstanceAccept = true
        C_Timer.After(15, function() TM.pendingInstanceAccept = false end)
        for _, fname in ipairs({"LFGDungeonReadyPopup", "LFGDungeonReadyDialog", "LFGProposalFrame"}) do
          local fr = _G[fname]
          if fr and fr:IsShown() then
            TM.AcceptInstanceProposal()
            TM.pendingInstanceAccept = false
            TM.DebugPrint("Auto-accept LFG via", fname)
            break
          end
        end

      elseif kind == "portal" then
        -- Portail monde : chercher n'importe quelle popup d'entrée d'instance
        local confirmed = false
        for i = 1, 10 do
          local popup = _G["StaticPopup" .. i]
          if popup and popup:IsShown() then
            local w = popup.which or ""
            if w:find("INSTANCE") or w:find("ENTER") or w:find("LOCK") then
              pcall(ConfirmEnterInstance)
              confirmed = true
              TM.DebugPrint("Auto-enter portail depuis leader (popup", w, ")")
              break
            end
          end
        end
        -- Fallback direct si aucun popup reconnu
        if not confirmed then pcall(ConfirmEnterInstance) end

      elseif kind == "delve" then
        -- Gouffre (Delve, TWW) : polling toutes les 0.5s jusqu'à ce que
        -- LFGDungeonReadyDialog ou un StaticPopup soit visible (timing variable)
        TM.pendingInstanceAccept = true
        C_Timer.After(30, function() TM.pendingInstanceAccept = false end)
        TM.DebugPrint("INSTENTER|delve: démarrage polling accept (30s)")
        TM.StartInstanceAcceptPoll(60)
      end
    end
    return
  end

  -- Delve direct enter: DELVEENTER|tier
  -- Côté membre : si la fenêtre DelvesDifficultyPickerFrame est ouverte, valider le tier directement.
  if mtype == "DELVEENTER" then
    if TM.db and TM.db.autoEnterInstance ~= false then
      local tier = tonumber(msg:match("^DELVEENTER|(.+)$")) or 1
      if C_DelvesUI and C_DelvesUI.SelectDelveEntranceTier
         and DelvesDifficultyPickerFrame and DelvesDifficultyPickerFrame:IsShown() then
        C_Timer.After(0, function()
          C_DelvesUI.SelectDelveEntranceTier(tier)
        end)
        TM.DebugPrint("Auto-enter delve tier=", tier, "depuis leader")
      else
        TM.DebugPrint("DELVEENTER reçu mais DelvesDifficultyPickerFrame fermé — skip")
      end
    end
    return
  end

  -- Delve exit: DELVEEXIT|1
  -- Côté membre : LFGTeleport(true) via SecureHandler pour quitter l'instance directement.
  -- Pas besoin de StaticPopup ni de polling : le membre n'a pas à confirmer manuellement.
  if mtype == "DELVEEXIT" then
    if TM.db and TM.db.autoEnterInstance ~= false then
      TM.DebugPrint("DELVEEXIT reçu: sortie Gouffre via SecureHandler")
      if TM.ConfirmDelveExit then TM.ConfirmDelveExit() end
    end
    return
  end

  -- Auto-mount : MOUNT|category
  -- Le leader vient d'invoquer une monture de catégorie `category`. Le membre tente
  -- d'invoquer une de ses montures favorites de la même catégorie (ou un fallback).
  if mtype == "MOUNT" then
    if TM.db and TM.db.autoMount ~= false then
      local category = msg:match("^MOUNT|(.+)$") or "ground"
      if IsMounted and IsMounted() then
        TM.DebugPrint("MOUNT reçu mais déjà monté, skip (category=", category, ")")
      elseif InCombatLockdown and InCombatLockdown() then
        TM.DebugPrint("MOUNT reçu mais en combat, skip")
      else
        local mountID, how = TM.PickFavoriteMountByCategory(category)
        if mountID and C_MountJournal and C_MountJournal.SummonByID then
          C_MountJournal.SummonByID(mountID)
          TM.DebugPrint("Auto-mount catégorie=", category, "mountID=", mountID, "(", how, ")")
        else
          TM.DebugPrint("Auto-mount : aucune monture favorite utilisable (category=", category, ")")
        end
      end
    end
    return
  end

  -- Auto-hearth : HEARTH|1
  if mtype == "HEARTH" then
    TM.DebugPrint("HEARTH reçu de", sender, "channel", channel, "msg=", msg)
    if not (TM.db and TM.db.autoHearth ~= false) then TM.DebugPrint("HEARTH reçu mais option désactivée") return end
    if IsMounted and IsMounted() then TM.DebugPrint("HEARTH reçu mais déjà monté, skip") return end
    if InCombatLockdown and InCombatLockdown() then TM.DebugPrint("HEARTH reçu mais en combat, skip") return end
    -- essai d'utiliser la pierre locale
    C_Timer.After(0, function()
      local ok = false
      if TM.TryUseHearth then ok = TM.TryUseHearth() end
      if ok then
        TM.DebugPrint("HEARTH reçu: tentative d'utilisation de la pierre locale effectuée (ok)")
      else
        TM.DebugPrint("HEARTH reçu: aucune pierre locale utilisée (nok)")
      end
    end)
    return
  end

  -- Team sync: TEAM|teamName|leaderFull|member1,member2,...
  local _, teamName, leaderFull, membersStr = msg:match("^(%a+)|([^|]*)|([^|]*)|(.*)$")
  if mtype ~= "TEAM" or not teamName or teamName == "" then return end
  if not TM.db.teams[teamName] then
    TM.db.teams[teamName] = { leader = nil, members = {} }
    TM.Print("Team synchronisée (nouvelle):", teamName)
  end
  local t = TM.db.teams[teamName]
  if leaderFull and leaderFull ~= "" then t.leader = leaderFull end
  if membersStr and membersStr ~= "" then
    local newMembers = {}
    for m in membersStr:gmatch("[^,]+") do table.insert(newMembers, m) end
    t.members = newMembers
  end
  -- N'auto-sélectionne la team que si le perso courant en est membre
  local playerShort = UnitName("player") or ""
  local isMember = false
  for _, m in ipairs(t.members) do
    local mshort = m:match("^(.-)%-") or m
    if mshort == playerShort then isMember = true; break end
  end
  if isMember then
    TM.selectedTeam = teamName
    TM.SaveSelectedTeamForCharacter(teamName)
  end
  TM.DebugPrint("Team sync reçue:", teamName, "| Leader:", t.leader or "(aucun)")
  local ui = TM.ui
  -- Rafraîchir l'UI quelle que soit la visibilité du panneau principal
  if ui then
    TM.RefreshTeamList()
    if isMember then
      TM.SelectTeam(teamName, false)
      -- Rafraîchir aussi la fenêtre flottante si elle est affichée
      if ui.floatingMemberList and ui.floatingMemberList:IsShown() then
        TM.RefreshFloatingMemberList()
      end
    end
  end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- Invite handshake receiver (TM.INVITE_PREFIX — always registered)
-- Handles TEAM_INVITE messages sent by the leader when they invite the team.
-- ────────────────────────────────────────────────────────────────────────────
local inviteHandshakeFrame = CreateFrame("Frame")
inviteHandshakeFrame:RegisterEvent("CHAT_MSG_ADDON")
inviteHandshakeFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
  if prefix ~= TM.INVITE_PREFIX then return end
  local me = UnitName("player")
  local senderShort = sender:match("^(.-)%-") or sender
  if senderShort == me then return end

  -- Format: TEAM_INVITE|teamName|leaderFull|member1,member2,...|syncPrefix
  -- Note: %w en Lua n'inclut PAS '_', on utilise [%w_]+ pour capturer TEAM_INVITE
  local mtype, teamName, leaderFull, membersStr, sentPrefix =
    msg:match("^([%w_]+)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
  if mtype ~= "TEAM_INVITE" or not teamName or teamName == "" then return end
  TM.DebugPrint("TEAM_INVITE reçu de", sender, "team=", teamName, "prefix=", sentPrefix)

  -- Toujours stocker les données de la dernière invite reçue
  TM.lastReceivedInvite = {
    teamName   = teamName,
    leaderFull = leaderFull,
    membersStr = membersStr,
    sentPrefix = sentPrefix,
  }

  local t = TM.db.teams[teamName]
  if t and TM.SYNC_PREFIX == sentPrefix then
    -- Team existe et le préfixe sync correspond → activation silencieuse
    TM.selectedTeam = teamName
    TM.SaveSelectedTeamForCharacter(teamName)
    TM.DebugPrint("Team |cffffcc00" .. teamName .. "|r activée automatiquement (sync OK).")
    local ui = TM.ui
    if ui and ui.frame and ui.frame:IsShown() then
      TM.RefreshTeamList()
      TM.SelectTeam(teamName, false)
    end
    if TM.UpdateFloatingTeamLabel then TM.UpdateFloatingTeamLabel(teamName) end
  else
    -- Team inconnue ou préfixe différent → popup de confirmation
    if TM.ShowInviteConfirmDialog then
      TM.ShowInviteConfirmDialog(TM.lastReceivedInvite)
    else
      -- UI pas encore construite : la popup s'ouvrira via /tm jointeam
      TM.Print("|cffffcc00[TeamManager]|r Invitation team \"" .. teamName
        .. "\" reçue. Tapez |cff00ffff/tm jointeam|r pour la rejoindre.")
    end
  end
end)
