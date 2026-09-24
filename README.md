# studio-configs

Configuration Claude Code de `~/Studio`, versionnée. Ce dépôt fait foi : les
deux fichiers ci-dessous sont liés par symlink dans `~/.claude/`, une
modification ici est active immédiatement.

## Contenu

| Fichier | Lié vers | Rôle |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | Règles de permission, appliquées par le harness |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Instructions globales, chargées dans chaque session |
| `docs/security/owasp.md` | | Ce qui est couvert, ce qui ne l'est pas |
| `promouvoir.sh` | | Promotion d'un brouillon vers le fichier actif |

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
le garde-fou, et la raison pour laquelle ce fichier est sous `deny`.

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
directement : le travail passe par un brouillon (`settings.draft.json`,
`CLAUDE.draft.md`), que je promeus moi-même dans mon terminal.

### Promouvoir un brouillon

Copier le brouillon à la main a un angle mort : un brouillon partiel remplace le
fichier entier. C'est arrivé en septembre 2026, le `CLAUDE.md` global est resté
un moment sans ses règles. La promotion passe donc par un script :

Depuis Git Bash, lancé à la racine du dépôt :

```bash
./promouvoir.sh CLAUDE.draft.md
./promouvoir.sh settings.draft.json --supprime 3
```

Depuis PowerShell, le script étant en Bash, il faut l'appeler par l'exécutable
de Git Bash. Ne pas écrire `bash` seul : sur ce poste, `bash` est celui de WSL,
qui voit d'autres chemins.

```powershell
& "C:\Program Files\Git\bin\bash.exe" -c "cd ~/Studio/studio-configs && ./promouvoir.sh CLAUDE.draft.md"
```

Le `&&` est ici dans la chaîne, donc lu par Bash. En PowerShell 5.1 il n'est pas
un séparateur valide : une commande par ligne, et `git -C <chemin>` plutôt qu'un
`cd` préalable.

Il affiche le diff avec le fichier actif, demande confirmation, puis écrit dans
la cible du lien symbolique : une copie à côté, renommée par-dessus, pour
qu'aucune session ne lise un fichier incomplet. Il refuse :

- un brouillon qui retire des lignes, sauf si `--supprime` en donne exactement
  le nombre. Une ligne modifiée compte comme une suppression : le compte
  s'annonce après lecture du diff, et un brouillon tronqué ne passe pas par
  inadvertance ;
- un brouillon dont les fins de ligne (CRLF ou LF) diffèrent de celles du
  fichier actif. Sinon toutes les lignes apparaîtraient modifiées, sans
  différence visible dans le diff, et `--supprime` du total les laisserait
  passer ;
- un `settings.draft.json` qui n'est pas du JSON valide ;
- un brouillon vide, ou une cible qui n'est pas un lien symbolique.

Il ne commite pas : relire `git diff` ici, puis commiter. Lancé par Claude, il
est annulé par la garde, ce qui est voulu.

Lancer la promotion quand aucune autre session Claude n'a de commande en cours :
la garde de cette session annulerait la promotion (voir ses limites plus bas).
Pour relire le diff sans rester bloqué dans le lecteur de pages, ajouter
`--no-pager` ; sinon, `q` pour en sortir.

```powershell
git -C "$HOME\Studio\studio-configs" --no-pager diff settings.json
```

## Lire le settings.json

Quatre points de mécanique, tous contre-intuitifs.

**1. L'ordre est `deny` → `ask` → `allow`, premier match gagnant.** La
spécificité ne compte pas : une règle large l'emporte sur une règle précise
placée plus bas. Un `deny` ne peut donc pas porter d'exception, et un `ask` non
plus : impossible d'autoriser `curl localhost` sous un `ask` sur `curl *`.

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
l'exécution arbitraire, dont `Bash(npm run *)`, et les restaure à la sortie.

## Les hooks

`settings.json` porte deux familles de hooks. Ils appliquent au même titre
qu'une règle de permission : ils s'exécutent en dehors du modèle. Leur différence
est qu'ils voient le **contenu** de l'appel ou l'état des fichiers, pas seulement
le nom de l'outil et le chemin.

### Refuser avant l'appel

Deux hooks `PreToolUse` s'exécutent avant l'outil et peuvent l'annuler.

| Matcher | Ce qu'il refuse | Pourquoi |
|---|---|---|
| `Bash` | Écrire dans une config protégée par un détour shell | Les règles `deny` ne couvrent qu'`Edit`. Sans ce hook, un `cat > settings.json` passerait sous la barrière. |
| `Write` | Un contenu portant un tiret cadratin | La règle de ponctuation du `CLAUDE.md` n'est qu'un panneau. Ce hook la rend appliquée. |

Deux limites connues, constatées à l'usage :

**Le hook `Write` ne distingue pas un tiret produit d'un tiret transporté.**
Recopier un fichier existant qui en contient est refusé, alors que rien de neuf
n'est écrit. Le remède est de traiter le cas au moment où il se pose, pas de
désarmer le hook.

**Il ne couvre pas `Edit`.** Étendre le matcher rendrait toute retouche
impossible dans un fichier déjà riche en tirets cadratins, et obligerait à
nettoyer l'existant pour avancer.

Dans le JSON, le caractère recherché est écrit en clair. La séquence
d'échappement Unicode de U+2014 fonctionnerait de la même façon, mais elle ne
tient pas :
l'application réécrit `settings.json` quand on change un réglage depuis son
interface, et décode l'échappement au passage (constaté en septembre 2026). Le
fichier contient donc le caractère qu'il interdit, sans conséquence : le hook
contrôle les écritures de l'outil `Write`, pas celles de l'application.

### La garde de la config

Les règles `deny` et le hook `Bash` visent des façons d'écrire. Ils ne voient pas
une modification qui arrive par un autre chemin : modifier la copie de
`settings.json` dans un worktree, commiter, fusionner dans `master`. C'est git
qui réécrit le fichier, et le lien symbolique le rend actif aussitôt (constaté
en septembre 2026). Un script, l'outil PowerShell ou un `cd` avant la commande
passent de la même façon.

La garde surveille le résultat plutôt que le chemin. Elle protège
`settings.json` et `CLAUDE.md`, rien d'autre.

| Événement | Ce qu'il fait |
|---|---|
| `PreToolUse` | Copie les deux fichiers dans `$TMPDIR/claude-garde-config/<tool_use_id>/` |
| `PostToolUse`, `PostToolUseFailure` | Compare, remet l'original si un fichier a changé, le signale dans la section System. Ne restaure jamais depuis une copie vide, ni depuis un `settings.json` invalide : le signale seulement |
| `ConfigChange` (`user_settings`) | Pendant un appel d'outil en cours, empêche la session d'appliquer un `settings.json` modifié |

Le hook `ConfigChange` protège la garde elle-même. Le file watcher recharge les
hooks en cours de session : sans lui, une commande qui retire la garde du
fichier la désactiverait avant qu'elle agisse.

Les hooks d'appel ignorent `Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch`,
`ToolSearch` et `AskUserQuestion`, qui n'écrivent rien, ainsi qu'`Agent` et
`Workflow`, qui durent le temps d'un sous-agent dont chaque appel passe déjà
par la garde.

Conséquence voulue : une modification de config faite par Claude est annulée,
quel que soit le chemin. Elle passe par un brouillon, promu avec
`promouvoir.sh`.

#### Copie vide et restauration par renommage

Le 24 septembre 2026, la garde a vidé le `CLAUDE.md` global. Sa copie de
sauvegarde était vide, et elle l'a restaurée telle quelle. Cause probable : la
copie a été prise pendant qu'une autre session réécrivait le fichier, à un
instant où `cat >` l'avait déjà tronqué sans l'avoir encore rempli. Le
`settings.json` était exposé de la même façon, et vide, il n'aurait plus porté
aucune règle `deny`.

Deux corrections, dans le hook de restauration :

- **Une copie vide n'est jamais restaurée**, ni une copie de `settings.json`
  qui n'est pas du JSON valide. Le cas est signalé dans la section System
  (« copie de sauvegarde vide ou invalide »), et le fichier reste tel quel.
- **La restauration écrit une copie à côté de la cible, puis la renomme**, au
  lieu de tronquer puis réécrire le fichier en place. Une autre session ne
  lit plus jamais un fichier vide ou à moitié écrit. Le renommage vise la
  cible du lien (`readlink -f`), pas le lien : renommer sur le lien le
  remplacerait par un fichier ordinaire, sorti de git. Si le renommage
  échoue (fichier verrouillé par Windows), la garde revient à `cat >` plutôt
  que de ne rien restaurer.

`promouvoir.sh` écrit de la même façon, par renommage : pendant une promotion,
le fichier n'est jamais vide ni à moitié écrit.

Limites acceptées, le périmètre est choisi :

- **Un appel refusé laisse sa copie dix minutes.** Un refus de permission ne
  déclenche pas `PostToolUse`. Pendant ce délai, un réglage changé depuis
  l'interface ne s'applique pas à la session en cours, sans message ; il
  s'applique à la suivante.
- **Une modification légitime faite pendant qu'une commande tourne est
  annulée**, quelle que soit la session qui exécute cette commande : réglage
  changé depuis l'interface, promotion, `git restore`. Le 24 septembre 2026,
  une promotion de `settings.json` a été annulée par la garde d'une autre
  session. Promouvoir quand aucune autre session n'a de commande en cours.
- **Les commandes en arrière-plan** continuent après le contrôle.
- **Des appels simultanés**, dans un ordre précis, peuvent laisser passer une
  modification.
- **Les copies sont dans un dossier inscriptible** : une injection qui connaît
  le mécanisme peut les modifier.
- **`settings.local.json` et les settings de projet ne sont pas gardés.**
- **Chaque appel d'outil lance deux `bash` de plus.**

Testé sur des fichiers ordinaires avant installation. La restauration à travers
le lien symbolique est confirmée par un cas réel (septembre 2026) : une
modification de `CLAUDE.md` faite pendant un appel d'outil a été annulée.
La version du 24 septembre 2026 a été testée sur une fausse config reliée par
de vrais liens symboliques : restauration à l'octet près, fins de ligne
conservées, liens intacts, copie vide et JSON invalide non restaurés.

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
`LinkType: SymbolicLink`. C'est le seul moyen de distinguer un lien d'une
copie. Puis `/permissions` dans une session liste les règles actives et leur
provenance.

## À adapter

**La liste `allow` est une hypothèse.** Elle suppose une stack npm. La laisser
minimale et la faire grossir depuis l'usage réel, pas par anticipation.

**Resserrer se fait au niveau du dépôt.** Un `ask` dans le
`.claude/settings.json` d'un projet bat un `allow` global. C'est ce qui permet
d'être permissif ici : la générosité en global est rattrapable, la sévérité ne
l'est pas.

**`remoteControlAtStartup` ouvre le pont à chaque session.** La session locale
devient pilotable depuis claude.ai, donc depuis un mobile. C'est commode, et
c'est une ouverture réelle sur une machine qui traite des données sensibles.
L'équivalent ponctuel est `claude --rc` au lancement, qui ne laisse rien
d'ouvert en permanence.

**Verrous optionnels :** `permissions.disableBypassPermissionsMode` et
`permissions.disableAutoMode`, à `"disable"`, empêchent définitivement l'usage
de ces modes.

**Révision :** relire via `/permissions` au bout de quelques semaines. Les
listes d'autorisation accumulent des entrées ajoutées dans le feu de l'action.

## Références

Syntaxe et comportement des règles : `https://code.claude.com/docs/en/permissions`
et `https://code.claude.com/docs/en/permission-modes`.

Plusieurs comportements sont récents : extension du `deny` `Read` aux éditions
(v2.1.208) et aux écritures (v2.1.228), ancrage des settings locaux (v2.1.211).
Vérifier `claude --version` avant de considérer un comportement comme acquis.

Constitué en août 2026, sur la base d'un bundle de configuration de sécurité
retravaillé règle par règle.
