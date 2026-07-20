---
layout: default
title: 設定と外観
---

# 設定と外観

`Z` または `Command+,` で設定ウィンドウを開きます。ここでは起動時の場所、操作前の確認、ファイル一覧の表示、テーマ、キーバインドなどを変更できます。

![設定ウィンドウ](../assets/screenshots/settings-window.png)

## General

General では、アプリの表示言語、Return キーの動作、インクリメンタルサーチの照合方法、起動時の左右ペインの場所を設定できます。

Return キーの動作は、メインペインの修飾キーなし `Return` だけに適用されます。既定では選択中ディレクトリへ移動しますが、ファイルをプレビューしてディレクトリは移動する、または何もしない動作にも変更できます。

インクリメンタルサーチは、前方一致、部分一致、完全一致から選べます。

## 操作と確認

コピー、移動、ゴミ箱への移動、終了前の確認を個別に切り替えられます。ファイル操作の明細ログ表示件数も設定できます。`0` を指定すると全件を表示します。

マーク後にカーソルを移動する、作成したフォルダへ移動する、親ディレクトリへ戻った後に元のディレクトリを選択する、といった操作挙動も設定できます。

## 組み込みテーマ

Light、Dark、Dracula、Nord、Solarized Light、Solarized Dark の組み込みテーマを選べます。作業環境や好みに合わせて、一覧の背景色・文字色・強調色を切り替えられます。

| Light | Dark |
| --- | --- |
| ![Light テーマ](../assets/screenshots/theme-light.png) | ![Dark テーマ](../assets/screenshots/theme-dark.png) |
| Dracula | Nord |
| ![Dracula テーマ](../assets/screenshots/theme-dracula.png) | ![Nord テーマ](../assets/screenshots/theme-nord.png) |
| Solarized Light | Solarized Dark |
| ![Solarized Light テーマ](../assets/screenshots/theme-solarized-light.png) | ![Solarized Dark テーマ](../assets/screenshots/theme-solarized-dark.png) |

## カスタムテーマ

組み込みテーマを起点にせず、表示色を自分の好みに合わせて調整することもできます。選択行、マーク済み行、メッセージ領域などを区別しやすい配色にできます。

![カスタムテーマの例](../assets/screenshots/theme-custom.png)

## ファイル別設定

拡張子ごとに、指定アプリと一覧表示色を設定できます。指定アプリを登録したファイルは、既定の `Control+Return` でそのアプリケーションから開けます。

## ゼブラ表示

「背景色を交互に切り替える」を有効にすると、ファイル一覧の行の背景色が交互に変わります。横に長い一覧で行を追いやすくしたい場合に便利です。

![Dark テーマでのゼブラ表示](../assets/screenshots/theme-dark-zebra.png)

次へ: [キーバインド](keybindings.md)
