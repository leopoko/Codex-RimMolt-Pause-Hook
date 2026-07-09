# Codex RimMolt Pause Hook

Codex が compact する直前に、RimMolt 経由で RimWorld を一時停止する Windows 向け hook です。

Auto Compact や手動 `/compact` のタイミングで RimWorld が進み続ける事故を減らすための小さなツールです。

## 何をするものか

- Codex の `PreCompact` hook で動きます。
- `manual` compact と `auto` compact の両方で動きます。
- RimMolt の MCP サーバーに `set_speed pause` を送ります。
- 通常のターン終了時には動きません。
- Windows 標準の PowerShell だけで動きます。
- Python や Node.js は不要です。

## プロジェクトはどう識別されるか

Codex は、開いているプロジェクトの `.codex/hooks.json` を読んで hook を有効にします。

このツールの `install.ps1` は、`install.ps1` が置かれているフォルダを「対象プロジェクトのルート」として扱い、そこに次のファイルを作成・更新します。

```text
対象プロジェクト\.codex\hooks.json
```

つまり、hook を効かせたい Codex プロジェクトのフォルダで `install.ps1` を実行してください。

例:

```text
H:\work\MyRimWorldCodexProject
├─ install.ps1
├─ uninstall.ps1
├─ hooks\
│  └─ pause-rimmolt.ps1
└─ .codex\
   └─ hooks.json
```

この場合、Codex で `H:\work\MyRimWorldCodexProject` を開いたときだけ、この hook が使われます。

## 必要なもの

- Windows
- Codex
- RimWorld
- RimMolt
- RimMolt の MCP サーバーが `http://localhost:8787/mcp` で動いていること

## 導入方法

1. この配布物を、hook を効かせたい Codex プロジェクトのフォルダに置きます。
2. PowerShell でそのフォルダを開きます。
3. 次のコマンドを実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

4. Codex を再起動するか、新しい Codex セッションを開始します。
5. Codex が hook の信頼確認を出した場合は、内容を確認して許可します。

デフォルトでは、そのプロジェクトの `.codex/hooks.json` だけを変更します。ユーザー全体の `%USERPROFILE%\.codex\hooks.json` は変更しません。

## 動作確認

RimWorld のセーブをロードし、RimMolt が起動している状態で次を実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hooks\pause-rimmolt.ps1
```

成功すると RimWorld が一時停止します。

セーブをロードしていない場合は、次のような表示になります。

```text
RimMolt did not pause: No colony is currently loaded.
```

これは RimMolt への接続はできているが、一時停止する対象のコロニーがない状態です。

## MCP URL を変える場合

RimMolt の MCP URL が違う場合は、インストール時に指定できます。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -McpUrl "http://localhost:8787/mcp"
```

## すべての Codex プロジェクトで使いたい場合

通常はおすすめしません。特定の RimWorld 用プロジェクトだけに設定する方が安全です。

どうしてもユーザー全体に設定したい場合だけ、次を使います。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Global
```

この場合は、プロジェクト内の `.codex/hooks.json` に加えて、ユーザー全体の `%USERPROFILE%\.codex\hooks.json` にも hook を追加します。

## アンインストール

対象プロジェクトから hook を削除する場合:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

`-Global` でユーザー全体にも設定していた場合:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Global
```

## 配布する場合

このリポジトリ全体を zip にしてください。利用者は zip を対象プロジェクトに展開して、`install.ps1` を実行するだけで使えます。

含まれる主なファイル:

- `hooks/pause-rimmolt.ps1`: RimMolt に pause を送る本体
- `install.ps1`: 対象プロジェクトに Codex hook を追加するインストーラ
- `uninstall.ps1`: Codex hook を削除するアンインストーラ
- `.codex/hooks.json`: プロジェクトローカル hook 設定の例

## トラブルシュート

RimWorld が止まらない場合は、次を確認してください。

- Codex で hook を設定したプロジェクトを開いている
- 対象プロジェクトに `.codex/hooks.json` がある
- Codex の hook 信頼確認を許可している
- Codex を再起動、または新しいセッションを開始している
- RimWorld でセーブをロードしている
- RimMolt が有効になっている
- `http://localhost:8787/mcp` にアクセスできる

標準では、RimMolt に接続できない場合でも Codex の作業を止めないように、終了コード `0` で終わります。開発や検証で失敗をエラー扱いしたい場合は、`hooks\pause-rimmolt.ps1` に `-StrictExit` を付けて実行してください。
