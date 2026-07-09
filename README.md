# Codex RimMolt Pause Hook

Codex のターン終了時に RimMolt へ「RimWorld を一時停止する」命令を送る Windows 向け hook です。

長時間の Codex 作業中や Auto Compact の前後で RimWorld が進み続ける事故を減らすためのものです。

## できること

- Codex の `Stop` hook で RimMolt の `set_speed` に `pause` を送ります。
- RimWorld が未ロード、RimMolt が未起動、Codex から接続できない場合でも Codex の作業自体は止めません。
- Windows 標準の PowerShell だけで動きます。Python や Node.js は不要です。

## 注意

現在確認できている Codex hook は `Stop` です。compact 専用の hook イベントは確認できていません。

そのため、このツールは「compact だけ」ではなく、Codex のターン終了時に毎回 pause を送ります。Auto Compact はターンの区切りで起きるため、実用上は compact 前後で RimWorld を止める用途に使えます。

## 必要なもの

- Windows
- Codex
- RimWorld
- RimMolt が有効で、MCP サーバーが `http://localhost:8787/mcp` で動いていること

## 導入方法

1. このフォルダを任意の場所に置きます。
2. PowerShell でこのフォルダを開きます。
3. 次のコマンドを実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

4. Codex を再起動するか、新しい Codex セッションを開始します。
5. 初回実行時に Codex が hook の信頼確認を出した場合は、内容を確認して許可します。

これでユーザー全体の Codex hook と、このプロジェクト内の `.codex/hooks.json` の両方に設定されます。

## 動作確認

RimWorld のセーブをロードし、RimMolt が起動している状態で次を実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hooks\pause-rimmolt.ps1
```

成功すると、RimWorld が一時停止します。

セーブをロードしていない場合は、次のような表示になります。

```text
RimMolt did not pause: No colony is currently loaded.
```

これは接続自体はできているが、停止対象のコロニーがない状態です。

## MCP URL を変える場合

RimMolt の MCP URL が違う場合は、インストール時に指定できます。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -McpUrl "http://localhost:8787/mcp"
```

## このプロジェクトだけに設定したい場合

ユーザー全体の hook を変更したくない場合は、次を使います。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -ProjectOnly
```

この場合は `.codex/hooks.json` だけを作成・更新します。

## アンインストール

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

プロジェクト内の hook だけを消す場合:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -ProjectOnly
```

## 配布する場合

配布時は、このリポジトリ全体を zip にしてください。利用者は zip を展開して `install.ps1` を実行するだけで使えます。

含まれる主なファイル:

- `hooks/pause-rimmolt.ps1`: RimMolt に pause を送る本体
- `install.ps1`: Codex hook を追加するインストーラ
- `uninstall.ps1`: Codex hook を削除するアンインストーラ
- `.codex/hooks.json`: プロジェクトローカル hook 設定

## トラブルシュート

RimWorld が止まらない場合は、次を確認してください。

- RimWorld でセーブをロードしている
- RimMolt が有効になっている
- `http://localhost:8787/mcp` にアクセスできる
- Codex の hook 信頼確認を許可している
- Codex を再起動、または新しいセッションを開始している

Codex に hook エラーを出したくないため、標準では RimMolt 接続失敗時も終了コード `0` で終わります。開発・検証で失敗をエラー扱いしたい場合は `-StrictExit` を付けてください。
