#!/bin/bash

set -euo pipefail

APP_DIR="${1:-Antlers.app}"
EXECUTABLE_PATH="${APP_DIR}/Contents/MacOS/Antlers"

if [ ! -d "${APP_DIR}" ]; then
    echo "エラー: アプリケーションバンドルが見つかりません: ${APP_DIR}"
    exit 1
fi

if [ ! -f "${EXECUTABLE_PATH}" ]; then
    echo "エラー: 実行ファイルが見つかりません: ${EXECUTABLE_PATH}"
    exit 1
fi

if find "${APP_DIR}" \( -name '.DS_Store' -o -name '*.dSYM' -o -name '*.o' \) -print -quit | grep -q .; then
    echo "エラー: 不要な同梱物が見つかりました"
    find "${APP_DIR}" \( -name '.DS_Store' -o -name '*.dSYM' -o -name '*.o' \) -print
    exit 1
fi

if strings "${EXECUTABLE_PATH}" | grep -E '/Users/|/home/|\.build/|antlers_MafxApp\.bundle|Sources/Mafx(App|Core)' >/dev/null; then
    echo "エラー: 実行ファイルにビルド環境のパスまたは SwiftPM resource bundle 名が残っています"
    strings "${EXECUTABLE_PATH}" | grep -E '/Users/|/home/|\.build/|antlers_MafxApp\.bundle|Sources/Mafx(App|Core)'
    exit 1
fi

if [ ! -d "${APP_DIR}/Contents/Resources/en.lproj" ] || [ ! -d "${APP_DIR}/Contents/Resources/ja.lproj" ]; then
    echo "エラー: ローカライズリソースがアプリケーションバンドルに同梱されていません"
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
echo "公開前チェックに合格しました: ${APP_DIR}"
