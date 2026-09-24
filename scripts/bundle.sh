#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/dist/Tagarela.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
mkdir -p ".cache/clang" ".cache/swiftpm"
CLANG_MODULE_CACHE_PATH="$project_dir/.cache/clang" \
SWIFTPM_CACHE_PATH="$project_dir/.cache/swiftpm" \
swift build -c release --disable-sandbox

mkdir -p "$contents_dir/MacOS"
cp ".build/release/tagarela" "$contents_dir/MacOS/tagarela"
cp "App/Info.plist" "$contents_dir/Info.plist"
mkdir -p "$contents_dir/Resources"
cp "App/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"
# Identidade estável (certificado local auto-assinado, só desta máquina).
# Ad-hoc (--sign -) gera uma cdhash nova a cada build, e o TCC amarra
# microfone/tela/acessibilidade a ela — por isso as permissões resetavam
# a cada rebuild. Com identidade fixa, concede-se uma vez só.
if [[ -n "${TAGARELA_SIGN_IDENTITY:-}" ]]; then
    signing_identity="$TAGARELA_SIGN_IDENTITY"
elif security find-certificate -c "Tagarela Local" >/dev/null 2>&1; then
    signing_identity="Tagarela Local"
else
    echo "Aviso: Certificado 'Tagarela Local' não encontrado. Assinando ad-hoc (-)." >&2
    signing_identity="-"
fi
codesign --force --deep --sign "$signing_identity" "$app_dir"

echo "$app_dir"
