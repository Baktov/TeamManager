# Copilot Instructions — TeamManager (WoW Addon)

## Contexte du projet

Addon World of Warcraft Retail (Interface 120000) dédié au **multiboxing**.
Permet de gérer des équipes (leader + membres), synchroniser des données entre clients, et afficher une interface graphique intégrée.

- **Langue du code** : commentaires en français, code en anglais (noms de variables/fonctions)
- **Auteur/style** : généré assisté par IA, convention de style minimaliste et lisible
- **Dépendance externe optionnelle** : ElvUI (skinning via `UI_Skin.lua`)

---

## Architecture

| Fichier | Rôle |
|---|---|
| `Core.lua` | Table globale `TM`, SavedVariables, utilitaires, CRUD équipes/membres |
| `Sync.lua` | Broadcast addon messages (C_ChatInfo), réception, sync XP/état |
| `UI_Skin.lua` | Skinning ElvUI conditionnel |
| `UI_Floating.lua` | Étiquette flottante + liste membres détachable |
| `UI_Minimap.lua` | Bouton minimap (LibDBIcon style) |
| `UI_Main.lua` | Fenêtre principale : `BuildUI`, `SelectTeam`, `RefreshTeamList`, `ToggleUI` |
| `Commands.lua` | Commandes slash `/tm` et keybindings |
| `Events.lua` | Handlers : `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT` |
| `Bindings.xml` | Déclaration XML des raccourcis WoW |
| `TeamManager.toc` | Manifeste de chargement |

**État partagé** : tout passe par la table globale `TM` (ex. `TM.db`, `TM.ui`, `TM.selectedTeam`).

---

## Conventions de code (à respecter impérativement)

1. **Pas de librairie externe** sauf ElvUI (optionnel, toujours protégé par `if ElvUI then`).
2. **Toutes les fonctions publiques** sont attachées à `TM` : `function TM.MaFonction() end`.
3. **Les fonctions locales** restent locales dans leur fichier.
4. **SavedVariables account-wide** → `TM.db` (= `TeamManagerDB`).
5. **SavedVariables per-character** → `TM.charDb` (= `TeamManagerCharDB`).
6. **Pas de `print()`** en production — utiliser `TM.Debug(msg)` qui respecte `TM.debugEnabled`.
7. **Messages sync** : toujours via `TM.SYNC_PREFIX` ou `TM.INVITE_PREFIX`, jamais en dur.
8. **UI** : frames créées avec `CreateFrame`, toutes référencées dans `TM.ui.*`.
9. **Ordre de chargement** respecte le `.toc` : ne jamais appeler une fonction d'un fichier chargé après.
10. **Pas de globals parasites** : toute variable de module doit être `local` ou sous `TM.`.

---

## Commandes slash disponibles

```
/tm create <nom>        — Créer une équipe
/tm delete <nom>        — Supprimer une équipe
/tm list                — Lister les équipes
/tm show <nom>          — Détails d'une équipe
/tm add <team> <joueur> — Ajouter un membre
/tm remove <team> <j>   — Retirer un membre
/tm setleader <team> <j>— Définir le leader
/tm addme <team>        — Ajouter le personnage courant
/tm addgroup <team>     — Ajouter les membres du groupe actuel
/tm ui                  — Ouvrir/fermer l'interface
/tm dump                — Debug : afficher toutes les équipes
/tm save                — Forcer ReloadUI
```

---

## Règles pour les modifications demandées à l'IA

- **Toujours lire** le fichier cible avant de le modifier.
- **Ne jamais créer** de nouveaux globals non préfixés `TM.`.
- **Tester mentalement** l'ordre de chargement (`.toc`) avant d'ajouter un appel inter-fichiers.
- **Conserver le bloc de commentaire** en tête de chaque fichier (`-- TeamManager: NomFichier — rôle`).
- Si une modification touche la synchronisation, **mettre à jour `Sync.lua` ET les handlers dans `Events.lua`**.
- Si une modification touche l'UI, vérifier la compatibilité **ElvUI** dans `UI_Skin.lua`.
- Toujours proposer le diff **fichier par fichier**.

---

## Patterns récurrents

### Ajouter une commande slash
→ Modifier uniquement `Commands.lua`, dans le bloc `elseif sub == "..."`.

### Ajouter un événement WoW
→ Enregistrer dans `Events.lua` (`frame:RegisterEvent`), handler dans le même fichier ou délégué vers `Core.lua`.

### Ajouter un champ persistant
→ Initialiser dans `Core.lua` avec une valeur par défaut sur `TeamManagerDB` ou `TeamManagerCharDB`.

### Ajouter un widget UI
→ Créer dans le fichier UI approprié, référencer via `TM.ui.monWidget`, skinning conditionnel dans `UI_Skin.lua`.

### Envoyer un message de synchronisation
→ Utiliser `TM.Broadcast(msg, channel)` défini dans `Sync.lua`.

### Référencer l'API Blizzard pour une nouvelle fonctionnalité
→ Avant d'implémenter tout appel à l'API WoW (frames, events, C_* namespaces…), consulter **wow-ui-source** pour vérifier la signature exacte et les patterns officiels Blizzard.
Deux sources disponibles, par ordre de préférence :
1. **Local** : `../wow-ui-source/` (même niveau que `TeamManager/` dans l'arborescence)
2. **GitHub** : [https://github.com/Gethe/wow-ui-source/](https://github.com/Gethe/wow-ui-source/)

Exemples d'usage :
- Vérifier les arguments d'un event → chercher le nom de l'event dans `wow-ui-source/Interface/FrameXML/`
- Vérifier une fonction `C_*` → chercher dans `wow-ui-source/Interface/AddOns/Blizzard_*/`
- Reproduire un widget Blizzard → s'inspirer du fichier source correspondant plutôt qu'inventer

### Afficher un message de debug dans le chat
→ **Toujours** utiliser `TM.Debug(msg)` — jamais `print()` directement.
`TM.Debug` n'affiche que si `TM.debugEnabled` est vrai (coché dans le panneau Options de l'UI).
```lua
-- ✅ Correct
TM.Debug("valeur reçue : " .. tostring(val))

-- ❌ Interdit
print("valeur reçue : " .. tostring(val))
```
Cela garantit que les logs disparaissent en production sans modifier le code.

---

### Implémenter une nouvelle fonctionnalité automatisée
Toute nouvelle fonctionnalité automatique (comportement déclenché sans action manuelle du joueur) **doit** :

1. **Être contrôlée par une checkbox dans le panneau Options** (`UI_Main.lua`, colonne droite).
   - Utiliser le pattern existant : `ui.maFonctToggle` + `TM.db.maFonctEnabled`
   - La valeur par défaut doit être explicite (`~= false` si activé par défaut, `== true` si désactivé par défaut)
   - La checkbox doit être restaurée dans `ADDON_LOADED` et `PLAYER_LOGIN` (`Events.lua`)

   ```lua
   -- UI_Main.lua — dans le bloc Options
   ui.maFonctToggle = CreateCheckbox(optPanel, "Libellé affiché", ...)
   ui.maFonctToggle:SetChecked(TM.db.maFonctEnabled ~= false)
   ui.maFonctToggle:SetScript("OnClick", function(self)
     TM.db.maFonctEnabled = self:GetChecked()
   end)

   -- Events.lua — dans ADDON_LOADED et PLAYER_LOGIN
   if ui.maFonctToggle then ui.maFonctToggle:SetChecked(TM.db.maFonctEnabled ~= false) end

   -- Sync.lua ou Events.lua — dans le handler
   if not (TM.db and TM.db.maFonctEnabled ~= false) then return end
   ```

2. **Être documentée dans `README.md`**, section **Panneau Options** :
   - Ajouter une ligne dans le tableau avec le nom exact du libellé de la checkbox, sa description et son état par défaut.

---

## Anti-patterns à éviter

- ❌ `print()` sans condition de debug
- ❌ Variables globales hors `TM.*`
- ❌ `C_ChatInfo.SendAddonMessage` appelé directement hors `Sync.lua`
- ❌ Hard-coder le préfixe `"TM_SYNC"` — utiliser `TM.SYNC_PREFIX`
- ❌ Créer des frames hors des fichiers `UI_*.lua`
- ❌ Modifier `TeamManager.toc` sans vérifier les dépendances inter-fichiers
