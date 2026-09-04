#!/bin/bash

# エラーが発生したら処理を中断
set -e

APP_NAME="Antlers"
APP_BUNDLE_IDENTIFIER="io.github.fukurozuno.antlers"
APP_VERSION="0.6.0"
APP_BUILD_VERSION="1"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
APP_ICON_SOURCE="Assets.xcassets/AppIcon.appiconset/1024.png"
APP_ICON_NAME="AppIcon"
APP_ICONSET_DIR=".build/${APP_ICON_NAME}.iconset"
LOCALIZATION_SOURCE_DIR="Sources/MafxApp/Resources"

echo "=== 1. SwiftPM リリースビルドの実行 ==="
swift build -c release

echo "=== 2. .app バンドルのフォルダ構造を作成 ==="
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

echo "=== 3. バイナリのコピー ==="
if [ ! -f "${BUILD_DIR}/${APP_NAME}" ]; then
    echo "エラー: 実行ファイルが見つかりません: ${BUILD_DIR}/${APP_NAME}"
    exit 1
fi
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

echo "=== 4. ローカライズリソースのコピー ==="
if [ ! -d "${LOCALIZATION_SOURCE_DIR}" ]; then
    echo "エラー: ローカライズリソースが見つかりません: ${LOCALIZATION_SOURCE_DIR}"
    exit 1
fi
cp -R "${LOCALIZATION_SOURCE_DIR}/." "${APP_DIR}/Contents/Resources/"
cp "THIRD_PARTY_NOTICES.md" "${APP_DIR}/Contents/Resources/THIRD_PARTY_NOTICES.md"

echo "=== 5. アプリアイコンの生成 ==="
if [ ! -f "${APP_ICON_SOURCE}" ]; then
    echo "エラー: アプリアイコン画像が見つかりません: ${APP_ICON_SOURCE}"
    exit 1
fi

rm -rf "${APP_ICONSET_DIR}"
mkdir -p "${APP_ICONSET_DIR}"

sips -z 16 16 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${APP_ICON_SOURCE}" --out "${APP_ICONSET_DIR}/icon_512x512.png" >/dev/null
cp "${APP_ICON_SOURCE}" "${APP_ICONSET_DIR}/icon_512x512@2x.png"

iconutil -c icns "${APP_ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/${APP_ICON_NAME}.icns"

echo "=== 6. Info.plist の作成 ==="
cat <<EOF > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_BUNDLE_IDENTIFIER}</string>
    <key>CFBundleIconFile</key>
    <string>${APP_ICON_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "=== 7. デバッグシンボルの除去 ==="
strip -S "${APP_DIR}/Contents/MacOS/${APP_NAME}"

echo "=== 8. アプリケーションへの簡易署名 ==="
codesign --force --deep --sign - "${APP_DIR}"

echo "=== 完了しました！ ${APP_DIR} が作成されました ==="
