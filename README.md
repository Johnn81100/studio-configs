# studio-configs

Configuration Claude Code de `~/Studio`, versionnée. Ce dépôt fait foi : les
deux fichiers ci-dessous sont liés par symlink dans `~/.claude/`, une
modification ici est active immédiatement.

## Contenu

| Fichier | Lié vers | Rôle |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | Règles de permission, appliquées par le harness |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Instructions globales, chargées dans chaque session |
| `docs/security/owasp.md` | — | Ce qui est couvert, ce qui ne l'est pas |

`settings.local.json` reste hors du dépôt (gitignoré) : il est propre à la
machine et accumule les autorisations ponctuelles.

## Le principe

**`settings.json` applique, `CLAUDE.md` influence.**

Les règles de permission sont appliquées par Claude Code, en dehors du modèle :
une règle `deny` bloque un appel d'outil quoi que le modèle décide. Les
instructions du `CLAUDE.md` passent par le modèle : elles orientent ce qu'il
essaie de faire, pas ce qui lui est autorisé.

Conséquence sur la répartition : ce qui doit tenir face à un contenu hostile va
dans `settings.json`. Une consigne de sécurité écrite en prose dans le
`CLAUDE.md` est un panneau, pas une barrière.

Une exception qui compte : en mode auto, le classifier lit le `CLAUDE.md` mais
ne reçoit pas les résultats d'outils. C'est le seul canal par lequel on informe
le garde-fou — et la raison pour laquelle ce fichier est sous `deny`.

## Le contrôle repose sur git

Il n'y a plus d'étape de copie. Un changement écrit ici est actif avant d'être
relu. Ce qui remplace la relecture avant installation :

```bash
git status        # un fichier de config a bougé
git diff          # quoi exactement
git commit        # le geste délibéré
```

Si cette habitude se perd, il ne reste rien entre une modification et son effet.
Les règles `deny` sur `settings.json` et `CLAUDE.md` empêchent que je les écrive
directement — le travail passe par un brouillon (`settings.fusion.json`), la
promotion est manuelle.

## Lire le settings.json

Quatre points de mécanique, tous contre-intuitifs.

**1. L'ordre est `deny` → `ask` → `allow`, premier match gagnant.** La
spécificité ne compte pas : une règle large l'emporte sur une règle précise
placée plus bas. Un `deny` ne peut donc pas porter d'exception, et un `ask` non
plus — impossible d'autoriser `curl localhost` sous un `ask` sur `curl *`.

**2. `deny` bloque sans prompt**, dans tous les modes, y compris
`bypassPermissions`. Pas de « autoriser cette fois ». Seul l'irrécupérable y va ;
le destructeur mais légitime est en `ask`.

**3. Un `ask` explicite prompte même en mode auto.** C'est ce qui le rend
collant : l'option « Yes, and don't ask again » écrit dans `allow`, qui perd
contre `ask`. Une règle `ask` ne peut pas être désactivée par impatience.

**4. Les chemins s'ancrent sur la source du fichier.** En scope utilisateur, un
pattern `/chemin` se résout sur `~/.claude/chemin`. D'où l'usage exclusif de
`~/` et de `**/` dans les règles de ce dépôt.

Le mode auto retire par ailleurs les règles `allow` larges accordant de
l'exécution arbitraire — dont `Bash(npm run *)` — et les restaure à la sortie.

## Installation

Sous Windows, `ln -s` de Git Bash **copie en silence** quand le privilège
manque : la commande semble réussir et le lien n'existe pas. Passer par
PowerShell, avec le mode développeur activé :

```powershell
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\settings.json" -Target "$HOME\Studio\studio-configs\settings.json"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\CLAUDE.md"     -Target "$HOME\Studio\studio-configs\CLAUDE.md"
```

Sauvegarder les fichiers existants d'abord : `New-Item` échoue si un fichier du
même nom occupe la place. Vérifier ensuite que `Get-Item` affiche bien
`LinkType: SymbolicLink` — c'est le seul moyen de distinguer un lien d'une
copie. Puis `/permissions` dans une session liste les règles actives et leur
provenance.

## À adapter

**La liste `allow` est une hypothèse.** Elle suppose une stack npm. La laisser
minimale et la faire grossir depuis l'usage réel, pas par anticipation.

**Resserrer se fait au niveau du dépôt.** Un `ask` dans le
`.claude/settings.json` d'un projet bat un `allow` global. C'est ce qui permet
d'être permissif ici : la générosité en global est rattrapable, la sévérité ne
l'est pas.

**Verrous optionnels :** `permissions.disableBypassPermissionsMode` et
`permissions.disableAutoMode`, à `"disable"`, empêchent définitivement l'usage
de ces modes.

**Révision :** relire via `/permissions` au bout de quelques semaines. Les
listes d'autorisation accumulent des entrées ajoutées dans le feu de l'action.

## Références

Syntaxe et comportement des règles : `https://code.claude.com/docs/en/permissions`
et `https://code.claude.com/docs/en/permission-modes`.

Plusieurs comportements sont récents — extension du `deny` `Read` aux éditions
(v2.1.208) et aux écritures (v2.1.228), ancrage des settings locaux (v2.1.211).
Vérifier `claude --version` avant de considérer un comportement comme acquis.

Constitué en août 2026, sur la base d'un bundle de configuration de sécurité
retravaillé règle par règle.
