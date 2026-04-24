# TeamManager

Addon WoW pour gérer des équipes (leader + membres) avec interface graphique, synchronisation et fenêtre flottante.
Dédié et concu pour le multiboxing.

Remerciement : Moorea, EbonyFaye

Addon codé IA (multiples). 

---

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `Core.lua` | Initialisation (`TM`), SavedVariables, utilitaires, gestion équipes/membres |
| `Sync.lua` | Broadcast et réception des messages addon (sync équipe + stats XP) |
| `UI_Skin.lua` | Support ElvUI (skinning fenêtre, minimap, étiquette flottante) |
| `UI_Floating.lua` | Étiquette flottante et liste membres détachable |
| `UI_Minimap.lua` | Bouton minimap |
| `UI_Main.lua` | `BuildUI`, `SelectTeam`, `RefreshTeamList`, `ToggleUI` |
| `Commands.lua` | Commandes slash `/tm` et keybindings globaux |
| `Events.lua` | Événements `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT` |
| `Bindings.xml` | Déclaration des raccourcis clavier WoW |
| `TeamManager.toc` | Manifeste — définit l'ordre de chargement des fichiers |

> L'état global partagé entre fichiers est exposé via la table `TM` (ex. `TM.db`, `TM.ui`, `TM.selectedTeam`).

---

## Commandes slash (`/tm`)

| Commande | Description |
|---|---|
| `/tm create <nom>` | Créer une équipe |
| `/tm delete <nom>` | Supprimer une équipe |
| `/tm list` | Lister les équipes |
| `/tm show <nom>` | Afficher les détails d'une équipe |
| `/tm add <team> <joueur>` | Ajouter un membre (nom ou Nom-Realm) |
| `/tm remove <team> <joueur>` | Enlever un membre |
| `/tm setleader <team> <joueur>` | Définir le leader |
| `/tm addme <team>` | Ajouter le personnage courant |
| `/tm addgroup <team>` | Ajouter les membres du groupe actuel |
| `/tm ui` | Ouvrir/fermer l'interface |
| `/tm dump` | Afficher toutes les équipes dans le chat (debug) |
| `/tm save` | Forcer un ReloadUI pour sauvegarder |

---

## Raccourcis clavier (Key Bindings)

Tous configurables dans le menu des raccourcis WoW sous **Team Manager** :

| Raccourci | Action |
|---|---|
| TeamManager: Se nommer leader | Se définir comme leader de l'équipe sélectionnée |
| TeamManager: Suivre le leader | Suivre le leader de l'équipe |
| TeamManager: Assister le leader | Cibler la cible du leader |
| TeamManager: Inviter la team | Inviter tous les membres en ligne |
| TeamManager: Ouvrir/Fermer l'interface | Basculer la fenêtre principale |

---

## Fenêtre principale (UI)

- **Redimensionnable** (min 600×340, taille sauvegardée par personnage)
- **Déplaçable** (position sauvegardée par personnage)
- **Mise en page 3 colonnes** :
  - **Colonne gauche** : liste scrollable des équipes (jusqu'à 12), clic pour sélectionner
  - **Colonne centrale** : liste des membres (jusqu'à 16) avec statut en ligne (vert) / hors ligne (rouge)
  - **Colonne droite** : panneau Options (debug, préfixe sync)

### Interactions sur les membres

| Action | Effet |
|---|---|
| **Clic gauche** | Inspecter le membre + surbrillance jaune |
| **Alt+Clic gauche** | Promouvoir le membre comme leader de l'équipe |
| **Alt+Clic droit** | Supprimer le membre de l'équipe |

Une infobulle rappelle ces raccourcis au survol de chaque ligne.

### Barre d'actions (haut de fenêtre)

- **Nom d'équipe** (EditBox) — champ de saisie en haut, aligné entre la liste et le bord droit de la fenêtre
- **Poignée de déplacement** (icône à gauche du nom d'équipe) : glisser-déposer pour créer l'étiquette flottante
- Boutons : **Add** · **Create** · **Delete** · **Add Me** · **Add Target** · **Add Group** · **Invite** · **Save**

### Panneau Options (colonne droite)

| Élément | Description |
|---|---|
| **Debug** (checkbox) | Active/désactive le mode debug (persistant) |
| **Préfixe sync** (EditBox) | Préfixe des messages addon (défaut : `TM_SYNC`). Valider avec **Entrée** applique le préfixe et force un `ReloadUI`. **Échap** annule. Tous les membres du groupe doivent utiliser le même préfixe. |
| **Affichage état follow/assist** (checkbox) | Affiche à gauche du nom de chaque membre (dans la liste flottante) la cible suivie/assistée, avec code couleur : **jaune** = follow uniquement · **vert** = assist uniquement ou follow+assist sur cibles différentes · **rouge** = follow et assist sur la même cible. Activé par défaut. |
| **Accepter les quêtes auto** (checkbox) | Si le leader accepte une quête, les membres de la team qui ont la fenêtre de quête ouverte (même PNJ ciblé) acceptent automatiquement. Activé par défaut. |
| **Sélection dialogue PNJ auto** (checkbox) | Si le leader clique sur une option de dialogue PNJ (phrase, cinématique…), les membres qui ont la même bulle de dialogue ouverte sélectionnent automatiquement la même option. Activé par défaut. |
| **Passer les cinématiques auto** (checkbox) | Si le leader passe (Échap) une cinématique moteur in-game ou une vidéo pré-rendue, les membres qui regardent la même cinématique la passent automatiquement. Activé par défaut. |
| **Vol automatique (maître de vol)** (checkbox) | Si le leader choisit une destination chez un maître de vol, les membres qui ont la même carte de vol ouverte prennent automatiquement la même destination. Activé par défaut. |

---

## Étiquette flottante (Floating Label)

Petit cadre déplaçable à l'écran affichant le nom de l'équipe sélectionnée.

| Action | Effet |
|---|---|
| **Clic gauche** | Inviter la team |
| **Shift+Clic gauche** | Ouvrir/fermer la fenêtre de configuration |
| **Clic droit** | Afficher/masquer la liste des membres |
| **Shift+Clic droit** | Supprimer l'étiquette flottante |
| **Glisser** | Repositionner (position sauvegardée) |

### Liste des membres flottante

Panneau extensible sous l'étiquette montrant tous les membres avec :
- Statut en ligne/hors ligne (couleur)
- Icône leader
- Niveau et % d'XP
- Icône de faction, race, classe
- Nom de la spécialisation

---

## Bouton minimap

| Action | Effet |
|---|---|
| **Clic gauche** | Ouvrir/fermer l'interface |
| **Clic droit** | Ouvrir/fermer l'interface |
| **Glisser** | Repositionner autour de la minimap (angle sauvegardé) |

---

## Synchronisation (Addon Comm)

Préfixe configurable (défaut : `TM_SYNC`) — canal RAID ou PARTY selon le contexte.

Le préfixe est modifiable depuis le **panneau Options** (colonne droite de la fenêtre principale). La valeur est sauvegardée dans `TeamManagerDB` et restaurée automatiquement au rechargement. **Tous les membres du groupe doivent utiliser le même préfixe** pour que la synchronisation fonctionne.

- **Sync équipe** : diffuse le nom d'équipe, leader et membres aux autres joueurs utilisant TeamManager. Crée automatiquement l'équipe si elle n'existe pas localement.
- **Sync XP/Niveau** : diffuse le niveau, % XP, classe, race, faction, spécialisation et sexe. Déclenché sur gain d'XP, montée de niveau, changement de groupe, changement de spécialisation et connexion.

---

## Sauvegarde et persistance

- Toutes les équipes sont sauvegardées dans `TeamManagerDB` (SavedVariables)
- **Données par personnage** : équipe sélectionnée, position/état de l'étiquette flottante, position/taille de la fenêtre
- Migration automatique de l'ancien format de données
- Conversion automatique en raid si plus de 5 invitations

---

## Compatibilité ElvUI

Skinning automatique de tous les éléments : fenêtre principale, boutons, editbox, checkbox, bouton minimap, étiquette flottante et liste des membres flottante.

