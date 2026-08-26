---
layout: default
title: 導入と初回起動
---

# 導入と初回起動

## 動作環境

- macOS 13 以降
- Xcode 15 以降（Swift 5.9 以降）

配布ページから Antlers を入手し、アプリケーションを起動します。初回起動時に macOS のセキュリティ警告が表示された場合は、信頼できる配布元から入手したことを確認してから、「システム設定」→「プライバシーとセキュリティ」→「このまま開く」を選びます。Gatekeeper を無効化する必要はありません。

## ソースから起動する

リポジトリを取得したディレクトリで、次を実行します。

```sh
swift build
swift run Antlers
```

テストは次のコマンドで実行できます。

```sh
swift test
```

ローカル実行用の `.app` バンドルを作成する場合は、次を実行します。

```sh
./bundle.sh
./scripts/verify-release.sh Antlers.app
```

`bundle.sh` で生成した `.app` は第三者配布用ではありません。配布する場合は Developer ID 署名と notarization を完了してください。

## 最初に見る画面

起動すると左右にファイル一覧、下部にメッセージ領域が表示されます。明るい枠で囲まれた側がアクティブペインです。`Shift+V` を押すか General の「プレビューペインを表示する」を有効にすると、左右どちらかに補助プレビューペインを表示できます。

次へ: [基本操作](basic-operations.md)
