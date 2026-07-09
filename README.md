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

デフォルトでは、そのプロジェクトの `.codex/hooks.json` に設定を追加または更新します。既存の他の hook は残します。ユーザー全体の `%USERPROFILE%\.codex\hooks.json` は変更しません。

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

リリース用 zip は GitHub Actions で自動作成されます。利用者は zip を対象プロジェクトに展開して、`install.ps1` を実行するだけで使えます。

配布 zip には `.codex/hooks.json` を入れません。利用者の既存 hook 設定を展開時に上書きしないためです。`.codex/hooks.json` は `install.ps1` が既存設定を読み込んでマージします。

含まれる主なファイル:

- `hooks/pause-rimmolt.ps1`: RimMolt に pause を送る本体
- `install.ps1`: 対象プロジェクトに Codex hook を追加するインストーラ
- `uninstall.ps1`: Codex hook を削除するアンインストーラ

## リリースする場合

GitHub Actions で配布用 zip を自動作成します。

タグを push すると、GitHub Release が作成され、次のファイルが添付されます。

- `Codex-RimMolt-Pause-Hook-<tag>.zip`
- `SHA256SUMS.txt`

例:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

GitHub の画面から Release を作成して公開した場合も、同じ zip が自動で添付されます。

手元で zip を確認したい場合:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 -Version test
```

生成物は `dist\` に出力されます。

## トラブルシュート

### `hook returned invalid PreCompact hook JSON output` と出る

古い設定では、hook スクリプトの結果表示が Codex の `PreCompact` hook 出力として解釈され、JSON ではないため失敗扱いになることがあります。

最新版では、Codex から呼ばれるときだけ `-CodexHook` を付け、標準出力を出さないようにしています。次をもう一度実行して `.codex/hooks.json` を更新してください。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

更新後の `.codex/hooks.json` 内の `pause-rimmolt.ps1` 呼び出しに `-CodexHook` が入っていれば修正済みです。

Codex が古い hook 定義を信頼済みとして覚えている場合は、Codex を再起動するか新しい Codex セッションを開始し、必要なら `/hooks` で新しい hook 定義を確認して許可してください。

### RimWorld が止まらない

RimWorld が止まらない場合は、次を確認してください。

- Codex で hook を設定したプロジェクトを開いている
- 対象プロジェクトに `.codex/hooks.json` がある
- Codex の hook 信頼確認を許可している
- Codex を再起動、または新しいセッションを開始している
- RimWorld でセーブをロードしている
- RimMolt が有効になっている
- `http://localhost:8787/mcp` にアクセスできる

標準では、RimMolt に接続できない場合でも Codex の作業を止めないように、終了コード `0` で終わります。開発や検証で失敗をエラー扱いしたい場合は、`hooks\pause-rimmolt.ps1` に `-StrictExit` を付けて実行してください。
