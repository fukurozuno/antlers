# Antlers

バージョン: `0.7.0`

Antlers は、macOS 向けのキーボードファーストな左右 2 ペイン型ファイラーです。
キーボードによる素早い移動と、安全なファイル操作を重視しています。

Version: `0.7.0`

Antlers is a keyboard-first, dual-pane file manager for macOS.
It focuses on fast navigation and safe file operations.

## 目次 / Contents

- [日本語](#日本語)
- [English](#english)

---

## 日本語

### 特徴

- 左右 2 ペインでコピー元とコピー先を同時に確認
- キーボード中心のカーソル移動、選択、ペイン切り替え
- コピー、移動、リネーム、ゴミ箱への移動
- 履歴、登録パス、パス直接入力によるナビゲーション
- 複数選択、ワイルドカードマーク、ファイルマスク
- ファイルのプレビュー、タグ検索、隠しファイル表示
- 設定画面からのキーバインド変更
- コマンドパレットで機能名やキーから操作を検索・実行
- 複数ストローク入力中のキー候補パネル表示
- 上書きや破壊的操作に対する確認

### あふw（AFXW）からの影響

Antlers は、あふw（AFXW）の操作感とキーボード中心のファイル操作に
インスピレーションを受けています。特に、左右 2 ペイン構成と、
キーボードでファイル整理を素早く行う考え方を参考にしています。

Antlers は独立したプロジェクトであり、あふw（AFXW）の公式な派生物、
公式な移植版、または関係プロジェクトではありません。

### 動作環境

- macOS 13 以降
- Xcode 15 以降（Swift 5.9 以降）

### ビルドと起動

リポジトリを取得したディレクトリで、次を実行します。

```sh
swift build
swift run Antlers
```

開発時には、次の起動オプションを利用できます。

```sh
swift run Antlers -- \
  --confined-root /path/to/root \
  --left-path subdirectory-a \
  --right-path subdirectory-b \
  --language ja \
  --theme dark
```

- `--confined-root`: 操作対象を指定ディレクトリ以下に限定します。
- `--left-path` / `--right-path`: 左右ペインの初期パスを指定します。`--confined-root` と併用した場合はルートからの相対パスです。
- `--language`: 起動時の言語を指定します（`ja` / `en` / `system`）。
- `--theme`: 起動時のテーマ ID を指定します。

これらは開発・検証用の起動オプションです。

テストは次のコマンドで実行できます。

```sh
swift test
```

macOS の `.app` バンドルを作成するには、次を実行します。`bundle.sh` はローカライズ資源とアプリアイコンを同梱し、ローカル実行用の ad hoc 署名を付与します。

```sh
./bundle.sh
./scripts/verify-release.sh Antlers.app
```

生成した `.app` は第三者配布用ではありません。第三者へ配布する場合は、Developer ID による署名と Apple の notarization を完了してください。

`bundle.sh` が生成するアプリの Bundle Identifier は `io.github.fukurozuno.antlers` です。この識別子はアプリの設定や署名に使用されるため、リリース後も変更しません。

### リリースノート / Release notes

- [V0.7.0 リリースノート](docs/ja/releases/v0.7.0.md)
- [V0.7.0 Release notes](docs/en/releases/v0.7.0.md)
- [V0.6.0 リリースノート](docs/ja/releases/v0.6.0.md)
- [V0.6.0 Release notes](docs/en/releases/v0.6.0.md)
- [V0.3.0 リリースノート](docs/ja/releases/v0.3.0.md)
- [V0.3.0 Release notes](docs/en/releases/v0.3.0.md)
- [V0.2.0 リリースノート](docs/ja/releases/v0.2.0.md)
- [V0.2.0 Release notes](docs/en/releases/v0.2.0.md)

### macOS のセキュリティ警告

現在配布している Antlers は、Developer ID によるコード署名および
Apple の notarization を行っていません。そのため、初回起動時に macOS が
「開発元を確認できない」などの警告を表示する場合があります。

信頼できる配布元からダウンロードしたことを確認したうえで起動してください。
起動を許可する場合は、アプリを一度開こうとした後、
「システム設定」→「プライバシーとセキュリティ」→「このまま開く」を選択します。
Gatekeeper を無効化する操作は推奨しません。

### 実装済みの主な機能

- 左右 2 ペインのファイル一覧
- ディレクトリ移動、親ディレクトリ移動、移動履歴
- 登録パス、場所一覧、パス直接入力
- カーソル移動、ページ移動、複数選択、範囲選択
- ファイルとディレクトリのマーク
- コピー、移動、リネーム、同一ディレクトリ内への別名コピー
- ゴミ箱への移動（恒久削除ではありません）
- フォルダ作成、ファイルをデフォルトアプリケーションで開く
- ファイルの Quick Look プレビュー
- インクリメンタルサーチ、ワイルドカードマーク、ファイルマスク
- ファイル名、拡張子、サイズ、更新日時によるソート
- 隠しファイル表示、ファイルアイコン、色タグ表示
- タグ検索とタグの設定・解除
- ペイン情報表示、メッセージ表示
- 設定画面、キーバインドの記録・変更
- コマンドパレットと、キーからの割り当て検索・変更

### 主要キーバインド

| キー | 操作 |
| --- | --- |
| `Tab` | アクティブペインを切り替える |
| `Left` / `Right` | 左右のペインをアクティブにする |
| `Up` / `Down` | カーソルを移動する |
| `PageUp` / `PageDown` | 1 ページ移動する |
| `Enter` | 選択中のディレクトリへ移動する（設定変更可） |
| `Backspace` | 親ディレクトリへ移動する |
| `Space` / `Shift+Space` | 項目をマークし、次または前へ移動する |
| `C` | マーク済み項目を逆窓へコピーする |
| `M` | マーク済み項目を逆窓へ移動する |
| `D` | マーク済み項目をゴミ箱へ移動する |
| `R` | 選択中項目をリネームする |
| `Shift+R` | 選択中項目を別名でコピーする |
| `V` | 選択中ファイルをプレビューする |
| `F` | インクリメンタルサーチを開始する |
| `H` | 履歴一覧を表示する |
| `J` | 登録パス一覧を表示する |
| `Shift+J` | パス入力欄を表示する |
| `S` | ソート指定を開始する |
| `O` / `Shift+O` | 左右ペインのパスを同期する |
| `Shift+?` / `Command+Shift+P` | コマンドパレットを開く |
| `Z` / `Command+,` | 設定ウィンドウを開く |
| `Q` | アプリケーションを終了する |

キーバインドは設定画面から変更できます。複数ストロークのキーバインドにも対応しています。
コマンドパレットはウィンドウ上部の `?` ボタンやヘルプメニューからも開けます。

デフォルトキーバインドの完全な一覧は [KEYBINDINGS.md](KEYBINDINGS.md) を参照してください。

複数ストロークの 1 ストローク目を入力すると、続けて入力できるキーとコマンドの候補を表示できます。候補パネルはキーボード操作を妨げず、マウスで候補をクリックするとそのコマンドを実行します。

### 安全設計

- 削除操作は恒久削除ではなく、ゴミ箱への移動として実行します。
- コピー、移動、リネームなどのファイル操作は専用サービスを経由します。
- 上書きが発生する操作は明示的な確認を要求します。
- UI からファイルシステムを直接操作しません。
- symlink を明示的な設計なしに再帰的にたどりません。

### ソースコードについて

ソースコード、テスト、ビルドスクリプトをこのリポジトリで公開しています。現時点では、ビルドとテストに必要な最小構成を提供します。

### ライセンス

Antlers は MIT License の下で公開しています。詳細は [LICENSE](LICENSE) を参照してください。

### 免責事項

重要なファイルを操作する前に、ユーザー自身でバックアップを確認してください。
本ソフトウェアは現状有姿で提供され、利用によって生じた損害について開発者は責任を負いません。

---

## English

### Features

- Dual-pane layout for viewing source and destination directories together
- Keyboard-first navigation, selection, and pane switching
- Copy, move, rename, and move-to-Trash operations
- Navigation history, bookmarks, and direct path input
- Multiple selection, wildcard marking, and file masks
- File preview, tag search, and hidden-file visibility
- Configurable keybindings
- Command palette for finding and running actions by name or key
- Candidate panel for multi-stroke key sequences
- Confirmation for overwrites and destructive operations

### Inspiration from あふw (AFXW)

Antlers is inspired by the interaction model and keyboard-focused file operations
of あふw (AFXW), especially its dual-pane layout and fast keyboard-driven workflow.

Antlers is an independent project. It is not an official derivative, port, or
affiliated project of あふw (AFXW).

### Requirements

- macOS 13 or later
- Xcode 15 or later (Swift 5.9 or later)

### Build and run

From the cloned repository, run:

```sh
swift build
swift run Antlers
```

Run the test suite with:

```sh
swift test
```

For development and verification, you can pass startup options:

```sh
swift run Antlers -- \
  --confined-root /path/to/root \
  --left-path subdirectory-a \
  --right-path subdirectory-b \
  --language en \
  --theme dark
```

- `--confined-root` limits operations to the specified directory and its contents.
- `--left-path` and `--right-path` set the initial pane paths. With `--confined-root`, they are relative to the confined root.
- `--language` sets the startup language (`ja`, `en`, or `system`).
- `--theme` sets the startup theme ID.

These options are intended for development and verification.

To generate a macOS `.app` bundle, run:

```sh
./bundle.sh
./scripts/verify-release.sh Antlers.app
```

`bundle.sh` includes localized resources and the app icon, then adds an ad hoc signature for local use. The resulting `.app` is not for third-party distribution. Sign with a Developer ID certificate and notarize it before distributing it to others.

Apps generated by `bundle.sh` use the Bundle Identifier `io.github.fukurozuno.antlers`. It is used for app preferences and signing, and will remain unchanged after release.

### macOS security warning

The currently distributed version of Antlers is not signed with a Developer ID
and has not been notarized by Apple. macOS may therefore display a warning such
as “developer cannot be verified” on first launch.

Only proceed after confirming that you obtained the app from a trusted source.
If you choose to open it, try launching the app once, then select
“System Settings” → “Privacy & Security” → “Open Anyway”.
Disabling Gatekeeper is not recommended.

### Implemented features

- Dual-pane file lists
- Directory navigation and navigation history
- Bookmarks, locations, and direct path input
- Cursor movement, page movement, multiple selection, and range selection
- File and directory marking
- Copy, move, rename, and copy with a new name
- Move to Trash instead of permanent deletion
- Folder creation and opening items with their default applications
- Quick Look file preview
- Incremental search, wildcard marking, and file masks
- Sorting by name, extension, size, and modification date
- Hidden files, file icons, and color tag display
- Tag search and tag editing
- Pane information, messages, and configurable keybindings
- Command palette and key-based shortcut search and reassignment

### Keybindings

| Key | Action |
| --- | --- |
| `Tab` | Switch the active pane |
| `Left` / `Right` | Activate the left or right pane |
| `Up` / `Down` | Move the cursor |
| `PageUp` / `PageDown` | Move by one page |
| `Enter` | Open the selected directory (configurable) |
| `Backspace` | Go to the parent directory |
| `Space` / `Shift+Space` | Mark an item and move forward or backward |
| `C` | Copy marked items to the opposite pane |
| `M` | Move marked items to the opposite pane |
| `D` | Move marked items to the Trash |
| `R` | Rename the selected item |
| `Shift+R` | Copy the selected item with a new name |
| `V` | Preview the selected file |
| `F` | Start incremental search |
| `H` | Show navigation history |
| `J` | Show bookmarks |
| `Shift+J` | Show direct path input |
| `S` | Start sort selection |
| `O` / `Shift+O` | Synchronize pane paths |
| `Shift+?` / `Command+Shift+P` | Open the command palette |
| `Z` / `Command+,` | Open Settings |
| `Q` | Quit the application |

Keybindings can be changed in Settings, including multi-stroke bindings.
You can also open the command palette from the `?` title-bar button or the Help menu.

See [KEYBINDINGS.md](KEYBINDINGS.md) for the complete list of default keybindings.

After the first stroke of a multi-stroke sequence, Antlers can show the remaining keys and command candidates. The candidate panel does not take keyboard focus; clicking a candidate with the mouse executes that command.

### Source code

This repository contains the source code, tests, and build scripts. At this stage it provides the minimum set required to build and test the project.

### License

Antlers is released under the MIT License. See [LICENSE](LICENSE) for details.

### Disclaimer

Please make sure that important files are backed up before performing file
operations. This software is provided “as is”; the developer is not responsible
for damage resulting from its use.
