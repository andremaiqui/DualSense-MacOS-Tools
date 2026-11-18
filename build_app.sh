#!/bin/bash
# Uso: ./build_app.sh [caminho/do/dsmactools]
# Gera DSUpdater.app com o dsmactools embutido.
set -euo pipefail
cd "$(dirname "$0")"

# Prefere o Xcode completo: as Command Line Tools não incluem todos os plug-ins
# de macro usados pelas versões atuais do SwiftUI.
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

CLI="${1:-$(command -v dsmactools || true)}"
[ -x "$CLI" ] || { echo "dsmactools não encontrado. Instale com Homebrew ou passe o caminho."; exit 1; }

swift build -c release
APP="DSUpdater.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/DSUpdater" "$APP/Contents/MacOS/"
cp "$CLI" "$APP/Contents/Resources/dsmactools"
cp Info.plist "$APP/Contents/"
codesign --force --deep --sign - "$APP"
echo "Pronto: $(pwd)/$APP"
