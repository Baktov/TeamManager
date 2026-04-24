-- TeamManager: Commands — slash commands and keybinding handlers

-- Secure button for assist action (Retail: actions protégées)
-- SetOverrideBindingClick redirige la touche directement vers ce bouton (vrai hardware event).
-- Aucun code addon dans la chaîne : pas de taint.
local _assistBtn = CreateFrame("Button", "TeamManagerAssistButton", UIParent, "SecureActionButtonTemplate")
_assistBtn:SetAttribute("type", "macro")
_assistBtn:SetAttribute("macrotext", "")
-- Pas de PreClick : tout code addon ici tainterait le contexte sécurisé
-- PostClick : s'exécute APRÈS la macro (hors hardware context, safe pour SendAddonMessage)
_assistBtn:SetScript("PostClick", function(self)
  if not TM or not TM.BroadcastMemberState then return end
  local newTarget = UnitName("target")
  if newTarget and newTarget ~= "" then
    TM.BroadcastMemberState("assist", newTarget)
    TM.DebugPrint("ASSIST PostClick: broadcast assist ->", newTarget)
  end
end)

function TM.RefreshAssistBinding()
  if InCombatLockdown() then return end
  ClearOverrideBindings(_assistBtn)
  local key1, key2 = GetBindingKey("TEAMMANAGER_ASSIST")
  if key1 then
    SetOverrideBindingClick(_assistBtn, true, key1, "TeamManagerAssistButton")
    TM.DebugPrint("AssistBinding: key1=", key1, "-> TeamManagerAssistButton")
  end
  if key2 then
    SetOverrideBindingClick(_assistBtn, true, key2, "TeamManagerAssistButton")
    TM.DebugPrint("AssistBinding: key2=", key2, "-> TeamManagerAssistButton")
  end
  if not key1 and not key2 then
    TM.DebugPrint("AssistBinding: aucune touche configurée pour TEAMMANAGER_ASSIST")
  end
end

function TM.UpdateAssistButton()
  if InCombatLockdown() then
    TM.DebugPrint("AssistButton: combat lockdown, mise à jour ignorée")
    return
  end
  local leader = TM.GetSelectedTeamLeaderShort()
  if not leader then
    _assistBtn:SetAttribute("macrotext", "")
    TM.DebugPrint("AssistButton vidé (pas de leader)")
    TM.RefreshAssistBinding()
    return
  end
  -- Utilise le token d'unité (ex: party1) pour éviter tout problème d'encodage du nom
  local unit = TM.FindUnitByName(leader)
  if unit then
    _assistBtn:SetAttribute("macrotext", "/assist " .. unit .. "\n/startattack")
    TM.DebugPrint("AssistButton: /assist", unit, "(", leader, ")")
  else
    _assistBtn:SetAttribute("macrotext", "/assist " .. leader .. "\n/startattack")
    TM.DebugPrint("AssistButton: /assist par nom (hors groupe):", leader)
  end
  TM.RefreshAssistBinding()
end

-- Binding: set self as leader for selected team
function TEAMMANAGER_SETLEADER()
  local team = TM.selectedTeam or TM.LoadSelectedTeamForCharacter()
  if not team then TM.Print("Aucune équipe sélectionnée"); return end
  local name = UnitName("player")
  local realm = GetRealmName() or ""
  local full = name
  if not full:match("%-") and realm ~= "" then full = full .. "-" .. realm end
  TM.SetLeader(team, full)
  local ui = TM.ui
  if ui and ui.frame and ui.frame:IsShown() then TM.SelectTeam(team) end
end

-- Binding: follow the selected team's leader
function TEAMMANAGER_FOLLOW()
  local leader = TM.GetSelectedTeamLeaderShort()
  if not leader then return end
  if leader == UnitName("player") then TM.Print("Vous êtes le leader"); return end
  local unit = TM.FindUnitByName(leader)
  if unit then
    TM.DebugPrint("FOLLOW: suivi de", leader, "(unit:", unit, ")")
    FollowUnit(unit)
    -- Le broadcast follow est géré via AUTOFOLLOW_BEGIN / AUTOFOLLOW_END dans Events.lua
  else
    TM.DebugPrint("FOLLOW: leader introuvable dans le groupe:", leader)
    TM.Print("Leader introuvable dans le groupe:", leader)
  end
end

-- Binding: assist the selected team's leader
-- Note: TEAMMANAGER_ASSIST() est un fallback ; SetOverrideBindingClick redirige
-- normalement la touche directement vers TeamManagerAssistButton (sans taint).
function TEAMMANAGER_ASSIST()
  TM.DebugPrint("ASSIST: appel direct (override binding non actif ?)") 
  TM.UpdateAssistButton()
end

-- Binding: invite all online members of the selected team
function TEAMMANAGER_INVITE()
  local team = TM.selectedTeam or TM.LoadSelectedTeamForCharacter()
  if not team then TM.Print("Aucune équipe sélectionnée"); return end
  local t = TM.db.teams[team]
  if t and t.leader then
    local leaderShort = t.leader:match("^(.-)%-") or t.leader
    if leaderShort ~= UnitName("player") then
      TM.Print("Seul le leader de la team peut inviter les membres (", t.leader, ")")
      return
    end
  end
  TM.InviteTeam(team)
end

-- Binding: toggle main UI
function TEAMMANAGER_TOGGLEUI()
  TM.ToggleUI()
end

-- Slash command handler
SLASH_TEAMMANAGER1 = "/tm"
SlashCmdList["TEAMMANAGER"] = function(msg)
  if not msg or msg == "" then
    TM.Print("Usage: /tm create|delete|list|show|add|remove|setleader|addme|addgroup|ui <args>")
    return
  end
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd and cmd:lower()
  if cmd == "ui" then
    TM.ToggleUI()
  elseif cmd == "create" then
    TM.CreateTeam(rest)
    TM.RefreshTeamList()
    TM.SelectTeam(rest)
  elseif cmd == "delete" then
    TM.DeleteTeam(rest)
    TM.RefreshTeamList()
    TM.SelectTeam(nil)
  elseif cmd == "list" then
    TM.ListTeams()
  elseif cmd == "show" then
    TM.ShowTeam(rest)
  elseif cmd == "add" then
    local team, who = rest:match("^(%S+)%s+(.+)$")
    if team and who then TM.AddMember(team, who) else TM.Print("Usage: /tm add <team> <player>") end
  elseif cmd == "remove" then
    local team, who = rest:match("^(%S+)%s+(.+)$")
    if team and who then TM.RemoveMember(team, who) else TM.Print("Usage: /tm remove <team> <player>") end
  elseif cmd == "setleader" then
    local team, who = rest:match("^(%S+)%s+(.+)$")
    if team and who then TM.SetLeader(team, who) else TM.Print("Usage: /tm setleader <team> <player>") end
  elseif cmd == "addme" then
    TM.AddMe(rest)
  elseif cmd == "addgroup" then
    TM.AddGroupMembers(rest)
  elseif cmd == "jointeam" then
    -- Ré-ouvre la popup d'invitation avec la dernière invite reçue
    if TM.lastReceivedInvite then
      if TM.ShowInviteConfirmDialog then
        TM.ShowInviteConfirmDialog(TM.lastReceivedInvite)
      else
        TM.BuildUI()
        TM.ShowInviteConfirmDialog(TM.lastReceivedInvite)
      end
    else
      TM.Print("Aucune invitation de team en attente.")
    end
  elseif cmd == "dump" then
    TM.Print("Dump des équipes:")
    for name, t in pairs(TM.db.teams) do
      TM.Print("Team:", name)
      TM.Print(" Leader:", t.leader or "(aucun)")
      for i, v in ipairs(t.members) do TM.Print("  ", i, v) end
    end
  elseif cmd == "save" then
    TM.Print("/tm save -> ReloadUI() pour forcer l'écriture des SavedVariables")
    ReloadUI()
  else
    TM.Print("Commande inconnue:", cmd)
  end
end
