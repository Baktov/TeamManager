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

-- Trigger XP broadcast on relevant events
local xpSyncFrame = CreateFrame("Frame")
xpSyncFrame:RegisterEvent("PLAYER_XP_UPDATE")
xpSyncFrame:RegisterEvent("PLAYER_LEVEL_UP")
xpSyncFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
xpSyncFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
xpSyncFrame:SetScript("OnEvent", function(self, event)
  TM.BroadcastXPSync()
  -- Quand le groupe change, le leader re-diffuse l'invite de team
  -- pour que les membres qui viennent de rejoindre la reçoivent.
  if event == "GROUP_ROSTER_UPDATE" and TM.pendingInviteTeam then
    local pendingTeam = TM.pendingInviteTeam
    local t = TM.db.teams[pendingTeam]
    if t and t.leader then
      local leaderShort = t.leader:match("^(.-)%-") or t.leader
      if leaderShort == UnitName("player") and IsInGroup() then
        C_Timer.After(0.5, function()
          TM.BroadcastTeamInvite(pendingTeam)
          TM.DebugPrint("GROUP_ROSTER_UPDATE: re-broadcast TEAM_INVITE pour", pendingTeam)
        end)
      end
    end
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
  if mtype == "QACCEPT" then
    if TM.db and TM.db.autoAcceptQuest ~= false then
      if QuestFrame and QuestFrame:IsShown() then
        AcceptQuest()
        TM.DebugPrint("Auto-accept qu\195\170te depuis leader")
      end
    end
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
  TM.selectedTeam = teamName
  TM.SaveSelectedTeamForCharacter(teamName)
  TM.Print("Team sync reçue:", teamName, "| Leader:", t.leader or "(aucun)")
  local ui = TM.ui
  if ui and ui.frame and ui.frame:IsShown() then
    TM.RefreshTeamList()
    TM.SelectTeam(teamName, false)
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
    TM.Print("Team |cffffcc00" .. teamName .. "|r activée automatiquement (sync OK).")
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
