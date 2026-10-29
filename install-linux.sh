#!/bin/sh
# install-linux.sh : installe ShamanRotation dans le dossier Interface/AddOns de WoW (Linux / Wine / Lutris)
# Usage : ./install-linux.sh "/chemin/vers/WoW/Interface/AddOns"
# Repare aussi une archive mal extraite : des fichiers plats nommes "ShamanRotation\xxx.lua" (antislash dans le nom) sont ranges dans un vrai dossier.
set -e
DEST="$1"
if [ -z "$DEST" ] || [ ! -d "$DEST" ]; then
  echo "Usage : $0 \"/chemin/vers/WoW/Interface/AddOns\"   (le dossier doit exister)"
  exit 1
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/ShamanRotation"
if [ ! -d "$SRC" ]; then
  mkdir -p "$SRC"
  for f in "$HERE"/ShamanRotation\\*; do
    [ -e "$f" ] || continue
    b="${f##*\\}"
    mv "$f" "$SRC/$b"
  done
fi
if [ ! -f "$SRC/ShamanRotation.toc" ]; then
  echo "ShamanRotation.toc introuvable dans $SRC : archive incomplete ?"
  exit 1
fi
rm -rf "$DEST/ShamanRotation"
cp -r "$SRC" "$DEST/ShamanRotation"
echo "Installe dans $DEST/ShamanRotation :"
ls "$DEST/ShamanRotation"
echo "Relance le jeu puis tape /shamrot diag pour verifier."