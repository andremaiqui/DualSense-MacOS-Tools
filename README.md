# DS Updater (SwiftUI)

Interface gráfica para o [dsmactools](https://github.com/olliejudge/dsmactools).
O app só chama o CLI (`--print-firmware-info --json`, `--check`, `--update-latest --yes`) e mostra o progresso.

## Compilar (macOS 26 (Tahoe) + Xcode 26, por causa do Liquid Glass)
    brew tap olliejudge/tap && brew install dsmactools   # ou passe o caminho do binário
    ./build_app.sh
    open DSUpdater.app

Para abrir no Xcode: `File > Open…` e escolha a pasta (Package.swift).
Sem embutir o binário, o app usa o do Homebrew (/opt/homebrew/bin ou /usr/local/bin).
