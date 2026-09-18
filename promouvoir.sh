#!/usr/bin/env bash
# Promouvoir un brouillon de config vers le fichier actif.
#
#   ./promouvoir.sh CLAUDE.draft.md
#   ./promouvoir.sh settings.draft.json --supprime 3
#
# Affiche le diff entre le fichier actif et le brouillon, demande confirmation,
# puis recopie le brouillon. Refuse si le brouillon retire des lignes, sauf si
# --supprime en donne exactement le nombre : une copie partielle ne passe pas
# par inadvertance. Une ligne modifiée compte comme une ligne supprimée.
#
# A lancer dans son propre terminal : lancé par Claude, la garde l'annule.
set -euo pipefail

usage() {
  echo "Usage : $0 <CLAUDE.draft.md|settings.draft.json> [--supprime N]" >&2
  exit 2
}

[ $# -ge 1 ] || usage
brouillon=$1
shift
attendu=0
if [ $# -gt 0 ]; then
  [ $# -eq 2 ] && [ "$1" = --supprime ] || usage
  case $2 in '' | *[!0-9]*) usage ;; esac
  attendu=$2
fi

case $(basename -- "$brouillon") in
  CLAUDE.draft.md) nom=CLAUDE.md ;;
  settings.draft.json) nom=settings.json ;;
  *) echo "Brouillon non reconnu : $brouillon" >&2; usage ;;
esac

lien=$HOME/.claude/$nom
[ -L "$lien" ] || { echo "$lien n'est pas un lien symbolique : promotion refusée." >&2; exit 1; }
cible=$(readlink -f -- "$lien")
[ -f "$cible" ] || { echo "Cible du lien introuvable : $cible" >&2; exit 1; }

[ -s "$brouillon" ] || { echo "Brouillon absent ou vide : $brouillon" >&2; exit 1; }
if [ "$nom" = settings.json ]; then
  jq empty "$brouillon" || { echo "JSON invalide : promotion refusée." >&2; exit 1; }
fi

if cmp -s -- "$cible" "$brouillon"; then
  echo "Aucune différence avec $cible."
  exit 0
fi

git -c core.autocrlf=false --no-pager diff --no-index -- "$cible" "$brouillon" || true
read -r ajout suppr _ < <(git -c core.autocrlf=false diff --no-index --numstat -- "$cible" "$brouillon" || true)

echo
echo "$nom : $ajout ligne(s) ajoutée(s), $suppr ligne(s) supprimée(s)."
if [ "$suppr" != "$attendu" ]; then
  echo "Refusé : le brouillon supprime $suppr ligne(s), $attendu annoncée(s)." >&2
  echo "Relire le diff. Si ces suppressions sont voulues :" >&2
  echo "  $0 $brouillon --supprime $suppr" >&2
  exit 1
fi

read -r -p "Promouvoir vers $cible ? [o/N] " reponse || reponse=
case $reponse in
  o | O) ;;
  *) echo "Abandon, rien n'a été écrit."; exit 1 ;;
esac

cat -- "$brouillon" > "$cible"
echo "Promu. Relire puis commiter : git -C \"$(dirname -- "$cible")\" diff"
