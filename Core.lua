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
-- Default options: enable auto-hearth by default unless explicitly disabled
if TM.db.autoHearth == nil then TM.db.autoHearth = true end
-- Default option: auto-accept LFG role check + proposal (dungeon entry)
if TM.db.autoEnterDungeon == nil then TM.db.autoEnterDungeon = true end

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

-- AcceptProposal() est une fonction protégée : elle ne peut être appelée que depuis
-- le Lua restreint (SecureHandlerBaseTemplate._onattributechanged).
-- Deux corrections critiques vs versions précédentes :
--   1. C_Timer.After(0) pour échapper au contexte CHAT_MSG_ADDON (qui bloque les handlers)
--   2. Compteur monotone (_seq) pour garantir que l'attribut CHANGE toujours
--   3. Pas de SetAttribute récursif dans le handler (cause d'erreurs silencieuses)
do
  local _f = CreateFrame("Frame", "TM_SecureAcceptFrame", UIParent, "SecureHandlerBaseTemplate")
  local _seq = 0

  -- Handler restreint : toutes les APIs d'entrée connues pour LFG/Delves TWW
  _f:SetAttribute("_onattributechanged", [[
    if name ~= "tm-accept" then return end
    -- LFGTeleport(false) = téléporter vers l'instance LFG/Delve (TWW)
    LFGTeleport(false)
    -- AcceptProposal = accepter une proposition LFG standard
    AcceptProposal()
    -- ConfirmEnterInstance = portails / instances monde
    ConfirmEnterInstance()
    -- Cliquer LFGDungeonReadyDialogEnterDungeonButton (même si visible=false)
    local enterBtn = self:GetFrameRef("lfgEnterBtn")
    if enterBtn then enterBtn:Click() end
    -- StaticPopup Button1 visible
    local btn
    btn = self:GetFrameRef("sp1")
    if btn and btn:IsShown() then btn:Click() end
    btn = self:GetFrameRef("sp2")
    if btn and btn:IsShown() then btn:Click() end
    btn = self:GetFrameRef("sp3")
    if btn and btn:IsShown() then btn:Click() end
    btn = self:GetFrameRef("sp4")
    if btn and btn:IsShown() then btn:Click() end
  ]])

  function TM.AcceptInstanceProposal()
    if InCombatLockdown() then
      TM.DebugPrint("AcceptInstanceProposal: en combat, skip")
      return false
    end
    -- Refs StaticPopup Button1
    for i = 1, 4 do
      local btn = _G["StaticPopup" .. i .. "Button1"]
      if btn then _f:SetFrameRef("sp" .. i, btn) end
    end
    -- Ref LFGDungeonReadyDialogEnterDungeonButton (cliquable même si visible=false)
    local enterBtn = _G["LFGDungeonReadyDialogEnterDungeonButton"]
    if enterBtn then _f:SetFrameRef("lfgEnterBtn", enterBtn) end
    _seq = _seq + 1
    local s = tostring(_seq)
    -- C_Timer.After(0) : échappe le contexte CHAT_MSG_ADDON
    C_Timer.After(0, function()
      _f:SetAttribute("tm-accept", s)
      TM.DebugPrint("AcceptInstanceProposal: SecureHandler déclenché (seq=" .. s .. ")")
    end)
    return true
  end
end

-- Validation de sortie de Gouffre (Delve TWW) : clic sur StaticPopup Button1 uniquement.
-- N'appelle PAS les APIs d'entrée (LFGTeleport / AcceptProposal / ConfirmEnterInstance).
do
  local _fExit = CreateFrame("Frame", "TM_SecureExitFrame", UIParent, "SecureHandlerBaseTemplate")
  local _seqExit = 0

  _fExit:SetAttribute("_onattributechanged", [[
    if name ~= "tm-exit" then return end
    -- LFGTeleport(true) = quitter l'instance LFG/Delve (TWW) sans popup
    LFGTeleport(true)
    -- Fallback : StaticPopup Button1 si une popup de confirmation est présente
    local btn
    btn = self:GetFrameRef("sp1")
    if btn and btn:IsShown() then btn:Click() end
    btn = self:GetFrameRef("sp2")
    if btn and btn:IsShown() then btn:Click() end
    btn = self:GetFrameRef("sp3")
    if btn and btn:IsShown() then btn:Click() end
    btn = self:GetFrameRef("sp4")
    if btn and btn:IsShown() then btn:Click() end
  ]])

  function TM.ConfirmDelveExit()
    if InCombatLockdown() then
      TM.DebugPrint("ConfirmDelveExit: en combat, skip")
      return false
    end
    for i = 1, 4 do
      local btn = _G["StaticPopup" .. i .. "Button1"]
      if btn then _fExit:SetFrameRef("sp" .. i, btn) end
    end
    _seqExit = _seqExit + 1
    local s = tostring(_seqExit)
    C_Timer.After(0, function()
      _fExit:SetAttribute("tm-exit", s)
      TM.DebugPrint("ConfirmDelveExit: SecureHandler déclenché (seq=" .. s .. ")")
    end)
    return true
  end
end

-- Polling : vérifie toutes les 0.5s si un StaticPopup de sortie est apparu.
-- Utilisé côté membre quand DELVEEXIT reçu avant que la popup n'apparaisse.
TM.pendingDelveExit = false
function TM.StartDelveExitPoll(remaining)
  remaining = remaining or 60
  if remaining <= 0 or not TM.pendingDelveExit then
    TM.DebugPrint("StartDelveExitPoll: arrêt (remaining=" .. tostring(remaining) ..
      " pending=" .. tostring(TM.pendingDelveExit) .. ")")
    return
  end
  for i = 1, 4 do
    local p = _G["StaticPopup" .. i]
    if p and p:IsShown() then
      TM.DebugPrint("StartDelveExitPoll: StaticPopup" .. i .. " trouvé -> ConfirmDelveExit")
      TM.pendingDelveExit = false
      TM.ConfirmDelveExit()
      return
    end
  end
  C_Timer.After(0.5, function() TM.StartDelveExitPoll(remaining - 1) end)
end

-- ─── SecureHandler pour AcceptRoleCheck() (fonction protégée TWW) ─────────
-- Appelé côté membre quand ROLECHECK est reçu du leader.
-- AcceptRoleCheck() valide le popup « Confirmez votre rôle » (LFG_ROLE_CHECK_SHOW).
do
  local _fRC = CreateFrame("Frame", "TM_SecureRoleCheckFrame", UIParent, "SecureHandlerBaseTemplate")
  local _seqRC = 0
  _fRC:SetAttribute("_onattributechanged", [[
    if name ~= "tm-rolecheck" then return end
    AcceptRoleCheck()
  ]])

  function TM.AcceptRoleCheckForDungeon()
    if InCombatLockdown and InCombatLockdown() then
      TM.DebugPrint("AcceptRoleCheckForDungeon: en combat, skip")
      return false
    end
    _seqRC = _seqRC + 1
    local s = tostring(_seqRC)
    C_Timer.After(0, function()
      _fRC:SetAttribute("tm-rolecheck", s)
      TM.DebugPrint("AcceptRoleCheckForDungeon: SecureHandler déclenché (seq=" .. s .. ")")
    end)
    return true
  end
end

-- Polling : vérifie toutes les 0.5s si le popup de rôle LFG est apparu.
-- Utilisé côté membre quand ROLECHECK reçu avant que la popup n'apparaisse.
-- Ne repose PAS sur la visibilité des frames (compatibilité ElvUI/DialogueUI) :
-- l'event LFG_ROLE_CHECK_SHOW (géré dans Events.lua) consommera pendingRoleCheck
-- dès qu'il fire côté membre, indépendamment de l'UI affichée.
-- Ce polling est un filet de sécurité supplémentaire via l'API GetLFGRoleUpdate.
TM.pendingRoleCheck = false
function TM.StartRoleCheckPoll(remaining)
  remaining = remaining or 30
  if remaining <= 0 or not TM.pendingRoleCheck then
    TM.DebugPrint("StartRoleCheckPoll: arrêt (remaining=" .. tostring(remaining) ..
      " pending=" .. tostring(TM.pendingRoleCheck) .. ")")
    return
  end
  -- Vérification API : C_LFGList ou GetLFGRoleUpdate indiquent si une vérification est en cours
  -- (compatible UI de base et ElvUI car indépendant de la visibilité des frames)
  local roleCheckActive = false
  if C_LFGList and C_LFGList.GetActiveEntryInfo then
    -- pas d'API directe de role-check status en TWW ; on se fie à l'event
    roleCheckActive = false
  end
  -- Fallback frames natifs (utile si LFG_ROLE_CHECK_SHOW n'a pas encore été reçu localement)
  for _, fname in ipairs({"LFGDungeonRoleCheckFrame", "LFGRoleCheckPopup"}) do
    local fr = _G[fname]
    if fr and fr:IsShown() then
      roleCheckActive = true
      TM.DebugPrint("StartRoleCheckPoll: " .. fname .. " visible -> AcceptRoleCheckForDungeon")
      break
    end
  end
  if roleCheckActive then
    TM.pendingRoleCheck = false
    TM.AcceptRoleCheckForDungeon()
    return
  end
  C_Timer.After(0.5, function() TM.StartRoleCheckPoll(remaining - 1) end)
end

-- Polling : vérifie toutes les 0.5s si un dialog d'instance est apparu.
-- Utilisé côté membre quand INSTENTER reçu avant que la popup n'apparaisse.
function TM.StartInstanceAcceptPoll(remaining)
  remaining = remaining or 60
  if remaining <= 0 or not TM.pendingInstanceAccept then
    TM.DebugPrint("StartInstanceAcceptPoll: arrêt (remaining=" .. tostring(remaining) ..
      " pending=" .. tostring(TM.pendingInstanceAccept) .. ")")
    return
  end
  -- LFGDungeonReadyDialog (proposals LFG / Delves)
  local dlg = _G["LFGDungeonReadyDialog"]
  if dlg and dlg:IsShown() then
    TM.Print("[DIAG3] Poll: LFGDungeonReadyDialog shown")
    -- Diagnostic condensé (1 TM.Print par catégorie = pas de throttle chat)
    if remaining == 60 then
      -- 1. Enfants directs UIParent + ElvUIParent (tous, shown marqué *)
      local function dumpRoot(root)
        if not root then return end
        local parts = {}
        pcall(function()
          for _, c in ipairs({root:GetChildren()}) do
            local n = c:GetName() or "?"
            local s = c:IsShown() and "*" or ""
            parts[#parts+1] = n .. "[" .. c:GetObjectType() .. "]" .. s
          end
        end)
        TM.Print("[DIAG3]", (root:GetName() or "root") .. ":", table.concat(parts, " "))
      end
      dumpRoot(UIParent)
      dumpRoot(_G["ElvUIParent"])

      -- 2. Arbre LFGDungeonReadyDialog récursif, batché par 4
      local lfgOut = {}
      local function scanRec(f, depth)
        if depth > 8 then return end
        local ok, kids = pcall(function() return {f:GetChildren()} end)
        if not ok then return end
        for _, c in ipairs(kids) do
          local n = c:GetName() or "?"
          local s = c:IsShown() and "S" or "h"
          local e = (c.IsEnabled and c:IsEnabled()) and "E" or ""
          lfgOut[#lfgOut+1] = string.rep(".", depth) .. c:GetObjectType() .. " " .. n .. " " .. s .. e
          scanRec(c, depth + 1)
        end
      end
      pcall(scanRec, dlg, 1)
      if #lfgOut == 0 then
        TM.Print("[DIAG3] LFGDlg: aucun enfant")
      else
        for i = 1, #lfgOut, 4 do
          local batch = {}
          for j = i, math.min(i + 3, #lfgOut) do batch[#batch+1] = lfgOut[j] end
          TM.Print("[DIAG3] LFG|" .. table.concat(batch, " | "))
        end
      end

      -- 3. Module LFG d'ElvUI
      pcall(function()
        if not _G["ElvUI"] then TM.Print("[DIAG3] ElvUI=absent"); return end
        local E = ElvUI[1]
        local LFG = E and E.GetModule and E:GetModule("LFG", true)
        if not LFG then TM.Print("[DIAG3] ElvUI.LFG=absent"); return end
        local shown = {}
        for k, v in pairs(LFG) do
          if type(v) == "table" and type(v.IsShown) == "function" then
            local ok2, s = pcall(function() return v:IsShown() end)
            if ok2 and s then
              local fn = (v.GetName and v:GetName()) or k
              shown[#shown+1] = k .. "=" .. fn
            end
          end
        end
        TM.Print("[DIAG3] ElvUI.LFG frames shown: " .. (next(shown) and table.concat(shown, " ") or "aucun"))
      end)

      -- 4. StaticPopups visibles avec leur type
      local sps = {}
      for i = 1, 4 do
        local p = _G["StaticPopup" .. i]
        if p and p:IsShown() then sps[#sps+1] = "SP" .. i .. "=" .. tostring(p.which) end
      end
      TM.Print("[DIAG3] StaticPopups: " .. (#sps > 0 and table.concat(sps, " ") or "aucun"))
    end
    TM.AcceptInstanceProposal()
    TM.pendingInstanceAccept = false
    -- Second poll court : StaticPopup de confirmation éventuel
    local sub = 20
    local function pollPopup()
      if sub <= 0 then return end
      sub = sub - 1
      for i = 1, 4 do
        local p = _G["StaticPopup" .. i]
        if p and p:IsShown() then
          TM.DebugPrint("Poll2: StaticPopup" .. i .. " shown -> click")
          TM.AcceptInstanceProposal()
          return
        end
      end
      C_Timer.After(0.3, pollPopup)
    end
    C_Timer.After(0.3, pollPopup)
    return
  end
  -- StaticPopup quelconque visible
  for i = 1, 4 do
    local popup = _G["StaticPopup" .. i]
    if popup and popup:IsShown() then
      TM.DebugPrint("Poll: StaticPopup" .. i .. " shown -> click Button1")
      TM.AcceptInstanceProposal()
      TM.pendingInstanceAccept = false
      return
    end
  end
  C_Timer.After(0.5, function() TM.StartInstanceAcceptPoll(remaining - 1) end)
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
