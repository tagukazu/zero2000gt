# zero2000gt

## Claude Code のスキル / エージェントを VPS とローカルで共有する

VPS の `~/.claude/{skills,agents,commands}` をこのリポジトリの `.claude/` に取り込み、ローカルでも使えるようにします。
リポジトリの `.claude/` に入ったものは、このリポジトリを開いたとき（ローカル・Claude Code on the web とも）自動で読み込まれます。
`install` すると `~/.claude/` にコピーされ、どのプロジェクトからでも使えます。

### macOS / Linux / WSL / Git Bash

```bash
# 1. VPS からリポジトリへ取り込む（SSH で VPS に接続できること）
VPS_HOST=user@your-vps scripts/claude-sync.sh pull
git add .claude && git commit -m "Sync Claude skills/agents from VPS" && git push

# 2. ローカルの ~/.claude にインストール（全プロジェクトで使う場合）
scripts/claude-sync.sh install

# リポジトリを経由せず VPS から ~/.claude へ直接コピーする場合
VPS_HOST=user@your-vps scripts/claude-sync.sh direct

# ローカルで編集したものを VPS に戻す場合
VPS_HOST=user@your-vps scripts/claude-sync.sh push
```

VPS 側の場所やポートが違う場合は `VPS_CLAUDE_DIR=/path/to/.claude`、`VPS_SSH_PORT=2222` を指定してください。

### Windows (PowerShell)

```powershell
.\scripts\claude-sync.ps1 pull -VpsHost user@your-vps
.\scripts\claude-sync.ps1 install
```

同期後は Claude Code を再起動すると反映されます。
