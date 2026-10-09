# デフォルトキーバインド / Default Keybindings

このドキュメントは、初期設定で使用されるメインペインのデフォルトキーバインドを示します。
キーバインドは設定画面から変更できます。

This document lists the default keybindings for the main panes.
Keybindings can be changed in Settings.

## 基本操作 / Navigation

| キー / Key | 操作 / Action |
| --- | --- |
| `Up` | カーソルを上へ移動 / Move the cursor up |
| `Down` | カーソルを下へ移動 / Move the cursor down |
| `PageUp` | 1 ページ上へ移動 / Move up by one page |
| `PageDown` | 1 ページ下へ移動 / Move down by one page |
| `Left` | 左ペインをアクティブにする / Activate the left pane |
| `Right` | 右ペインをアクティブにする / Activate the right pane |
| `Tab` | アクティブペインを切り替える / Switch the active pane |
| `Option+Left` | 左ペインを狭くする / Narrow the left pane |
| `Option+Right` | 左ペインを広くする / Widen the left pane |
| `Option+Up` | メッセージウィンドウを高くする / Enlarge the message window |
| `Option+Down` | メッセージウィンドウを低くする / Shrink the message window |
| `Command+Left` | 履歴を戻る / Go back in navigation history |
| `Command+Right` | 履歴を進む / Go forward in navigation history |
| `Backspace` | 親ディレクトリへ移動 / Go to the parent directory |
| `Command+Enter` | 選択中項目を開く / Open the selected item |
| `V` | 選択中ファイルをプレビュー / Preview the selected file |

## 選択とマーク / Selection and Marking

| キー / Key | 操作 / Action |
| --- | --- |
| `Space` | マークを切り替え、次へ移動 / Toggle the mark and move forward |
| `Shift+Space` | マークを切り替え、前へ移動 / Toggle the mark and move backward |
| `Shift+Control+Space` | 直前のマークから現在位置までマーク / Mark from the previous mark to the current position |
| `End` | マークをすべて解除して再探索 / Clear all marks and reload the list |
| `A` | 表示中ファイルのマークを反転 / Invert marks for visible files |
| `Shift+A` | 表示中ファイルとディレクトリのマークを反転 / Invert marks for visible files and directories |
| `W` | 同名ファイル選択を表示 / Show same-name file selection |
| `I` | 選択中項目の情報を表示 / Show information for the selected item |

## ファイル操作 / File Operations

| キー / Key | 操作 / Action |
| --- | --- |
| `C` | マーク済み項目を逆窓へコピー / Copy marked items to the opposite pane |
| `M` | マーク済み項目を逆窓へ移動 / Move marked items to the opposite pane |
| `D` | マーク済み項目をゴミ箱へ移動 / Move marked items to the Trash |
| `R` | 選択中項目をリネーム / Rename the selected item |
| `Shift+R` | 選択中項目を別名でコピー / Copy the selected item with a new name |
| `K` | フォルダを作成 / Create a folder |

## 検索と表示 / Search and Display

| キー / Key | 操作 / Action |
| --- | --- |
| `F` | インクリメンタルサーチを開始 / Start incremental search |
| `Shift+@` | ワイルドカードマークを開始 / Start wildcard marking |
| `Shift+:` | ファイルマスク入力を開始 / Start file mask input |
| `S, S` | サイズ順でソート / Sort by file size |
| `S, E` | 拡張子順でソート / Sort by extension |
| `S, F` | ファイル名順でソート / Sort by file name |
| `S, T` | 更新日時順でソート / Sort by modification date |
| `T` | タグ一覧を表示 / Show the tag list |
| `Shift+T` | タグ設定一覧を表示 / Show tag editing |
| `L` | 場所一覧を表示 / Show the locations list |
| `J` | 登録パス一覧を表示 / Show the bookmark list |
| `Shift+J` | パス入力欄を表示 / Show direct path input |

## ペイン操作とアプリケーション / Pane and Application

| キー / Key | 操作 / Action |
| --- | --- |
| `O` | アクティブペインを逆窓のパスへ同期 / Sync the active pane to the opposite pane |
| `Shift+O` | 逆窓をアクティブペインのパスへ同期 / Sync the opposite pane to the active pane |
| `/` | 操作メニューを表示 / Show the operation menu |
| `Shift+?` / `Command+Shift+P` | コマンドパレットを表示 / Show the command palette |
| `Z` | 設定ウィンドウを開く / Open Settings |
| `Command+,` | 設定ウィンドウを開く / Open Settings |
| `Q` | アプリケーションを終了 / Quit the application |

## 予約キーとデフォルト割り当てなし / Reserved and Unassigned Keys

- 修飾キーなしの `Enter` は通常のキーバインドではありません。General の「Return キーの動作」設定で、ディレクトリ移動、ファイルプレビュー、または何もしない動作を選択します。
- Unmodified `Enter` is not a regular keybinding. Its behavior is controlled by the General “Return key behavior” setting: open directories, preview files and open directories, or do nothing.
- 隠しファイル表示の切り替えにはデフォルトのキー割り当てがありません。設定画面または任意のキー割り当てで利用できます。
- Hidden-file visibility has no default keybinding. It can be used from Settings or assigned to a key manually.
- `Esc` は入力欄、一覧、プレビューなどの現在のコンテキストでキャンセルまたは終了に使用します。
- `Esc` is used for canceling or closing the current input, list, or preview context.
- `Q` は通常は終了ですが、プレビュー表示中はプレビューを終了して一覧へ戻ります。
- `Q` normally quits the application, but closes the preview and returns to the list while previewing.

## キーバインドの変更 / Customization

設定画面の Keybindings で、コマンドごとに複数のキー列を登録できます。
`S, F` のような複数ストロークのキー列にも対応しています。
機能名やキーワードで検索でき、「キーから検索」では実際にキー列を入力して割り当てを調べられます。割り当て済みのキーは別の機能へ移動または解除でき、未割り当てのキーには機能を割り当てられます。変更は設定画面の OK で保存します。

In Settings → Keybindings, multiple key sequences can be assigned to each command,
including multi-stroke sequences such as `S, F`.
Search by command name or keyword, or use **Search by key** to enter a sequence and inspect its assignment. You can reassign or remove an assigned sequence, and assign an available sequence. Click OK in Settings to save changes.

## コマンドパレット / Command Palette

`Shift+?` または `Command+Shift+P` で開きます。ウィンドウ上部の `?` ボタンやヘルプメニューからも開けます。機能名、キーワード、キーで検索し、上下キーで選んで `Return` で実行します。`Esc` で閉じます。選択中の機能から「キー設定を開く」を選ぶと、その機能のキー設定へ移動できます。

Open with `Shift+?` or `Command+Shift+P`, the `?` title-bar button, or the Help menu. Search by command name, keyword, or key; use Up/Down and `Return` to run a command, or `Esc` to close. **Open Keybindings** jumps to the selected command's shortcut settings.

## 複数ストローク入力中の候補 / Multi-stroke Candidates

複数ストロークの 1 ストローク目を入力すると、続けて入力できるキーと
対応するコマンドの候補を表示できます。候補パネルはキーボードフォーカスを
受け取らないため、上下キーなどの入力は通常どおりメインペインで処理されます。
候補をマウスでクリックすると、対応するコマンドを直ちに実行します。

After entering the first stroke of a multi-stroke sequence, Antlers can show
the remaining keys and their command candidates. The candidate panel does not
take keyboard focus, so keyboard input such as Up and Down continues to be
handled by the main pane. Clicking a candidate executes the corresponding command immediately.
