# Conventions de studio-configs

Ce fichier précise les conventions propres à ce dépôt. Les règles du
`CLAUDE.md` global s'appliquent en plus, et priment en cas de conflit.

## Les deux fichiers globaux

`settings.json` et `CLAUDE.md` sont la copie de travail de `master`, liée par
symlink dans `~/.claude/`. Il n'existe pas de version en test sur une branche :
ce qui est sur `master` s'applique. Ils ne passent donc pas par une branche.

1. Claude écrit un brouillon à la racine : `CLAUDE.draft.md` ou
   `settings.draft.json`. C'est une copie complète du fichier actif, avec les
   mêmes fins de ligne, et pas un extrait.
2. Claude vérifie le nombre de lignes supprimées avec
   `git -c core.autocrlf=false diff --no-index --numstat` et l'annonce.
3. Je promeus depuis mon terminal, Windows PowerShell 5.1, où `bash` seul
   désigne WSL. Claude me donne la commande complète, avec le nom du brouillon,
   et `--supprime N` si l'étape 2 a compté N lignes supprimées :

   ```powershell
   & "C:\Program Files\Git\bin\bash.exe" -c "cd ~/Studio/studio-configs && ./promouvoir.sh CLAUDE.draft.md"
   ```

   Je relis `git diff` et je commite sur `master`. Les commandes git que Claude
   me donne passent par `git -C <chemin>` : pas de `&&` en PowerShell 5.1.
4. Le brouillon se supprime une fois la promotion commitée.

Claude ne promeut pas lui-même et ne fusionne pas une branche qui toucherait ces
fichiers : la garde annule le changement, mais le commit reste sur `master`.

## Les autres fichiers

README, `docs/`, `promouvoir.sh`, ce fichier :

- une branche `claude/<sujet>` depuis `master`, dans un worktree
  `.claude/worktrees/<sujet>` ;
- un commit par sujet sur la branche, sans PR ;
- avant de passer la main pour la fusion, Claude rebase la branche sur `master`
  (dans son worktree, seulement si elle n'a jamais été poussée) et montre
  `git diff --stat master..<branche>`. En cas de conflit, Claude annule le
  rebase et me le montre ;
- je fusionne en local, en avance rapide. Ensuite, branche et worktree se
  suppriment.

## Écritures de l'application

L'application réécrit `settings.json` quand un réglage change depuis son
interface. La modification apparaît sur `master`, hors de toute branche. C'est
attendu : Claude montre le diff, et le commit sur `master` dit que le fichier a
été réécrit par l'application.

## Sauvegarde

Le push reste à ma main. Après une fusion ou une promotion, Claude signale les
commits de `master` absents de `origin/master` (`git status -sb`).
