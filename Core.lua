-- TeamManager: Core — init, shared state, utilities, team management functions
local addonName = ...

-- SavedVariables table: TeamManagerDB (account-wide: teams)
if not TeamManagerDB then
  TeamManagerDB = { teams = {} }
end

-- SavedVariablesPerCharacter: TeamManagerCharDB (per-character: selectedTeam, etc.)
if not TeamManagerCharDB then
  TeamManagerCharDB = {}
end

TM = {}
TM.db = TeamManagerDB
TM.charDb = TeamManagerCharDB
TM.debugEnabled = TM.db.debug or false

-- UI and forward declarations so handlers in other files can reference them early
TM.ui = {}
local ui = TM.ui

-- Remap raceFile values that don't match atlas naming
TM.RACE_ATLAS_REMAP = {
  Scourge = "undead",
  HighmountainTauren = "highmountain",
  LightforgedDraenei = "lightforged",
}

-- Cache for level/XP data received from other group members
-- Key: short name, Value: { level=N, xpPct=N }
TM.memberXPCache = {}

-- Cache for follow/assist state broadcast by each member
-- Key: short name, Value: { follow="targetName", assist="targetName" }
TM.memberStateCache = {}

-- Keybinding header and names (appear in Key Bindings menu)
BINDING_HEADER_TEAMMANAGER = "Team Manager"
_G["BINDING_NAME_TEAMMANAGER_SETLEADER"] = "TeamManager: Se nommer leader"
_G["BINDING_NAME_TEAMMANAGER_FOLLOW"]    = "TeamManager: Suivre le leader"
_G["BINDING_NAME_TEAMMANAGER_ASSIST"]    = "TeamManager: Assister le leader"
_G["BINDING_NAME_TEAMMANAGER_INVITE"]    = "TeamManager: Inviter la team"
_G["BINDING_NAME_TEAMMANAGER_TOGGLEUI"]  = "TeamManager: Ouvrir/Fermer l'interface"

-- Addon communication prefix (configurable, saved in TM.db.syncPrefix)
TM.SYNC_PREFIX = "TM_SYNC"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
  C_ChatInfo.RegisterAddonMessagePrefix(TM.SYNC_PREFIX)
end

-- Fixed prefix for invite handshake — always registered, independent of configurable sync prefix
TM.INVITE_PREFIX = "TM_INV"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
  C_ChatInfo.RegisterAddonMessagePrefix(TM.INVITE_PREFIX)
end

-- Change the sync prefix at runtime: registers the new prefix and persists it.
function TM.SetSyncPrefix(newPrefix)
  if not newPrefix or newPrefix == "" then return end
  newPrefix = newPrefix:match("^%s*(.-)%s*$")
  if newPrefix == "" then return end
  TM.SYNC_PREFIX = newPrefix
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(TM.SYNC_PREFIX)
  end
  if TM.db then TM.db.syncPrefix = TM.SYNC_PREFIX end
  TM.DebugPrint("Préfixe sync mis à jour:", TM.SYNC_PREFIX)
end

-- ────────────────────────────────────────────────────────────────────────────
-- Utility functions
-- ────────────────────────────────────────────────────────────────────────────

function TM.Print(...)
  local prefix = "|cffff0000[TeamManager]|r"
  local parts = {}
  for i = 1, select('#', ...) do
    parts[i] = tostring(select(i, ...))
  end
  local msg = table.concat(parts, " ")
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. msg)
  else
    print(prefix .. " " .. msg)
  end
end

function TM.DebugPrint(...)
  if TM.debugEnabled then
    TM.Print(...)
  end
end

function TM.NormalizeName(name)
  if not name or name == "" then return nil end
  name = name:match("^%s*(.-)%s*$")
  return name
end

-- Per-character persistence helpers
function TM.GetCharacterKey()
  local name = UnitName("player") or "unknown"
  local realm = GetRealmName() or ""
  local full = name
  if not full:match("%-") and realm ~= "" then full = full .. "-" .. realm end
  return full
end

function TM.GetPerCharDB()
  return TM.charDb
end

function TM.SaveSelectedTeamForCharacter(team)
  if not TM.charDb then return end
  TM.charDb.selectedTeam = team
  TM.DebugPrint("Saved selected team (perChar) ->", tostring(team))
end

function TM.LoadSelectedTeamForCharacter()
  if TM.charDb and TM.charDb.selectedTeam then
    TM.DebugPrint("Loading selected team from charDb ->", TM.charDb.selectedTeam)
    return TM.charDb.selectedTeam
  end
  if TM.db then
    local key = TM.GetCharacterKey()
    TM.DebugPrint("No charDb entry, trying legacy key:", key)
    if TM.db.perCharData and TM.db.perCharData[key] and TM.db.perCharData[key].selectedTeam then
      local t = TM.db.perCharData[key].selectedTeam
      TM.charDb.selectedTeam = t
      return t
    end
    if TM.db.perChar then
      local v = TM.db.perChar[key]
      if not v then
        local short = (UnitName("player") or "")
        if short ~= "" then v = TM.db.perChar[short] end
      end
      if v then
        TM.charDb.selectedTeam = v
        return v
      end
    end
  end
  return nil
end

-- ────────────────────────────────────────────────────────────────────────────
-- Team management functions
-- ────────────────────────────────────────────────────────────────────────────

function TM.CreateTeam(name)
  name = TM.NormalizeName(name)
  if not name or name == "" then TM.Print("Nom d'équipe invalide"); return end
  if TM.db.teams[name] then TM.Print("L'équipe existe déjà:", name); return end
  local playerName = UnitName("player") or ""
  local realm = GetRealmName() or ""
  local fullName = playerName
  if not fullName:match("%-") and realm ~= "" then fullName = fullName .. "-" .. realm end
  TM.db.teams[name] = { leader = fullName, members = { fullName } }
  TM.Print("Équipe créée:", name, "— leader:", fullName)
end

function TM.DeleteTeam(name)
  name = TM.NormalizeName(name)
  if not TM.db.teams[name] then TM.Print("Équipe introuvable:", name); return end
  TM.db.teams[name] = nil
  TM.Print("Équipe supprimée:", name)
end

function TM.AddMember(team, fullname, skipOnlineCheck)
  team     = TM.NormalizeName(team)
  fullname = TM.NormalizeName(fullname)
  if not TM.db.teams[team] then TM.Print("Équipe introuvable:", team); return end
  if not fullname then TM.Print("Nom de membre invalide"); return end
  if not skipOnlineCheck and not TM.IsMemberOnline(fullname) then
    TM.Print("Membre non connecté — ajout annulé:", fullname); return
  end
  local t = TM.db.teams[team]
  for _, v in ipairs(t.members) do if v == fullname then TM.Print(fullname, "déjà membre"); return end end
  table.insert(t.members, fullname)
  TM.Print("Ajouté", fullname, "à", team)
end

function TM.RemoveMember(team, fullname)
  team     = TM.NormalizeName(team)
  fullname = TM.NormalizeName(fullname)
  if not TM.db.teams[team] then TM.Print("Équipe introuvable:", team); return end
  local t = TM.db.teams[team]
  for i, v in ipairs(t.members) do
    if v == fullname then
      table.remove(t.members, i)
      TM.Print("Supprimé", fullname, "de", team)
      if t.leader == fullname then t.leader = nil; TM.Print("Leader retiré car supprimé") end
      return
    end
  end
  TM.Print(fullname, "n'est pas membre de", team)
end

function TM.SetLeader(team, fullname)
  team     = TM.NormalizeName(team)
  fullname = TM.NormalizeName(fullname)
  if not fullname then TM.Print("Nom invalide pour leader"); return end
  if not TM.db.teams[team] then TM.Print("Équipe introuvable:", team); return end
  local t = TM.db.teams[team]
  local found = false
  for _, v in ipairs(t.members) do if v == fullname then found = true; break end end
  if not found then
    if TM.IsMemberOnline(fullname) then
      table.insert(t.members, fullname)
    else
      TM.Print("Leader hors-ligne — non ajouté à la team:", fullname)
    end
  end
  t.leader = fullname
  TM.DebugPrint("Leader pour", team, "->", fullname)
  TM.BroadcastTeamSync(team)
  if TM.UpdateAssistButton then TM.UpdateAssistButton() end
end

function TM.CompactMembersArray(arr)
  if not arr then return {} end
  local idxs = {}
  for k, v in pairs(arr) do
    if type(k) == "number" and v ~= nil then table.insert(idxs, k) end
  end
  table.sort(idxs)
  local out = {}
  for _, k in ipairs(idxs) do table.insert(out, arr[k]) end
  return out
end

function TM.IsMemberOnline(name)
  if not name or name == "" then return false end
  local short = name:match("^(.-)%-") or name
  if short == UnitName("player") then return true end
  if IsInGroup and IsInGroup() then
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, n do
      local unit = (IsInRaid and IsInRaid() and ("raid"..i)) or ("party"..i)
      if unit and UnitName(unit) and UnitName(unit) == short then return true end
    end
  end
  if GetFriendInfo and GetNumFriends then
    local numFriends = GetNumFriends() or 0
    for i = 1, numFriends do
      local fname, _, _, _, connected = GetFriendInfo(i)
      if fname then
        local fshort = fname:match("^(.-)%-") or fname
        if fshort == short and connected then return true end
      end
    end
  end
  if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
    if GuildRoster and type(GuildRoster) == "function" then GuildRoster() end
    local ng = GetNumGuildMembers() or 0
    for i = 1, ng do
      local gname, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
      if gname then
        local gshort = gname:match("^(.-)%-") or gname
        if gshort == short and online then return true end
      end
    end
  end
  return false
end

function TM.AnnouncePlayerTeam()
  if not TM.db or not TM.db.teams then return end
  local playerShort = UnitName("player") or ""
  local leaderOf, memberOf = {}, {}
  for name, t in pairs(TM.db.teams) do
    if t and t.leader then
      local lshort = t.leader:match("^(.-)%-") or t.leader
      if lshort == playerShort then table.insert(leaderOf, name) end
    end
    if t and t.members then
      for _, m in ipairs(t.members) do
        local mshort = m:match("^(.-)%-") or m
        if mshort == playerShort then table.insert(memberOf, name); break end
      end
    end
  end
  if #leaderOf == 0 and #memberOf == 0 then
    TM.Print("Aucune affiliation d'équipe pour ce personnage.")
  else
    if #leaderOf > 0 then TM.Print("Leader de:", table.concat(leaderOf, ", ")) end
    if #memberOf > 0 then TM.Print("Membre de:", table.concat(memberOf, ", ")) end
  end
end

function TM.ListTeams()
  TM.Print("Équipes sauvegardées:")
  local any = false
  for name, _ in pairs(TM.db.teams) do TM.Print(" -", name); any = true end
  if not any then TM.Print(" (aucune)") end
end

function TM.ShowTeam(name)
  name = TM.NormalizeName(name)
  local t = TM.db.teams[name]
  if not t then TM.Print("Équipe introuvable:", name); return end
  TM.Print("Équipe:", name)
  TM.Print(" Leader:", t.leader or "(aucun)")
  TM.Print(" Membres:")
  for i, v in ipairs(t.members) do TM.Print(string.format("  %d. %s", i, v)) end
end

function TM.AddMe(team)
  local name = UnitName("player")
  local realm = GetRealmName() or ""
  local full = name
  if not full:match("-") and realm ~= "" then full = full .. "-" .. realm end
  TM.AddMember(team, full)
end

function TM.AddGroupMembers(team)
  if not IsInGroup() then TM.Print("Pas dans un groupe"); return end
  for i = 1, GetNumGroupMembers() do
    local unit = (IsInRaid() and "raid"..i) or (IsInGroup() and "party"..i)
    local name = unit and UnitName(unit)
    if name then TM.AddMember(team, name) end
  end
  TM.AddMe(team)
end

function TM.InviteTeam(team)
  team = TM.NormalizeName(team or TM.selectedTeam)
  if not team then TM.Print("Aucune équipe sélectionnée"); return end
  local t = TM.db.teams[team]
  if not t then TM.Print("Équipe introuvable:", team); return end
  local leaderShort = t.leader and (t.leader:match("^(.-)%-") or t.leader) or nil
  if leaderShort ~= UnitName("player") then
    TM.Print("Seul le leader de la team peut inviter les membres (", tostring(t.leader), ")")
    return
  end
  local count = #t.members
  if count == 0 then TM.Print("Aucun membre à inviter pour", team); return end
  TM.DebugPrint("InviteTeam called for:", team, "members:", count)
  if count > 5 then
    if not IsInRaid() then
      if IsInGroup() then
        if UnitIsGroupLeader("player") then
          ConvertToRaid()
          TM.Print("Conversion du groupe en raid pour inviter", count, "membres")
        else
          TM.Print("Vous n'êtes pas leader — ne peut pas convertir en raid automatiquement")
        end
      end
    end
  end
  for _, who in ipairs(t.members) do
    if who and who ~= "" then
      if TM.IsMemberOnline(who) then
        local short = who:match("^(.-)%-") or who
        if short == UnitName("player") then
          TM.DebugPrint("InviteTeam: skipping self:", short)
        elseif TM.FindUnitByName(short) then
          -- Déjà dans le groupe WoW → pas d'invitation WoW (évite l'erreur "déjà dans un groupe")
          TM.DebugPrint("InviteTeam: déjà dans le groupe, pas d'InviteUnit pour:", short)
        else
          TM.DebugPrint("Inviting:", who, "(short:", short..")")
          local inviteFunc = nil
          if type(InviteUnit) == "function" then
            inviteFunc = InviteUnit
          elseif C_PartyInfo and type(C_PartyInfo.InviteUnit) == "function" then
            inviteFunc = C_PartyInfo.InviteUnit
          end
          if inviteFunc then
            local ok, err = pcall(inviteFunc, short)
            if not ok then TM.Print("Erreur Invite pour", short, "->", tostring(err)) end
          else
            TM.Print("API d'invitation indisponible pour", short)
          end
        end
      else
        TM.Print("Membre hors-ligne, invitation ignorée:", who)
      end
    end
  end
  TM.Print("Invitations envoyées pour l'équipe:", team)
  -- Mémorise la team pour re-diffuser l'invite sur GROUP_ROSTER_UPDATE
  -- (les membres acceptent l'invite WoW APRÈS cet appel, donc IsInGroup() est faux ici)
  TM.pendingInviteTeam = team
  -- Si déjà dans un groupe, diffuse immédiatement en plus
  if IsInGroup() and TM.BroadcastTeamInvite then
    TM.BroadcastTeamInvite(team)
  end
end

function TM.FindUnitByName(shortName)
  if not IsInGroup() then return nil end
  local prefix = IsInRaid() and "raid" or "party"
  local count = GetNumGroupMembers() or 0
  for i = 1, count do
    local unit = prefix .. i
    if UnitName(unit) == shortName then return unit end
  end
  return nil
end

function TM.InspectMember(name)
  if not name or name == "" then return end
  local short = name:match("^(.-)%-") or name
  local me = UnitName("player")
  if short == me then ToggleCharacter("PaperDollFrame"); return end
  local unit = TM.FindUnitByName(short)
  TM.DebugPrint("InspectMember: short=", short, "unit=", tostring(unit))
  if not unit then
    TM.Print("[TeamManager] " .. short .. " introuvable dans le groupe (doit être en ligne et dans votre groupe).")
    return
  end
  InspectUnit(unit)
end

function TM.GetSelectedTeamLeaderShort()
  local team = TM.selectedTeam or TM.LoadSelectedTeamForCharacter()
  if not team then TM.Print("Aucune équipe sélectionnée"); return nil end
  local t = TM.db.teams[team]
  if not t or not t.leader then TM.Print("Aucun leader pour l'équipe sélectionnée"); return nil end
  return t.leader:match("^(.-)%-") or t.leader
end
