#!/usr/bin/env bash
# VPS 上の Claude Code スキル / エージェント / コマンドをローカルと同期する。
#
# 使い方:
#   VPS_HOST=user@example.com scripts/claude-sync.sh pull     # VPS -> リポジトリの .claude/
#   scripts/claude-sync.sh install                            # リポジトリの .claude/ -> ~/.claude/（全プロジェクトで使える）
#   VPS_HOST=user@example.com scripts/claude-sync.sh direct   # VPS -> ~/.claude/ に直接コピー
#   VPS_HOST=user@example.com scripts/claude-sync.sh push     # リポジトリの .claude/ -> VPS
#
# 環境変数:
#   VPS_HOST        SSH 接続先 (必須: pull/direct/push)。~/.ssh/config の Host 名でも可
#   VPS_CLAUDE_DIR  VPS 側の .claude ディレクトリ (既定: ~/.claude)
#   VPS_SSH_PORT    SSH ポート (既定: 22)
#   LOCAL_CLAUDE_DIR ローカルのインストール先 (既定: ~/.claude)
set -euo pipefail

KINDS=(skills agents commands)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_CLAUDE_DIR="$REPO_DIR/.claude"
VPS_CLAUDE_DIR="${VPS_CLAUDE_DIR:-~/.claude}"
VPS_SSH_PORT="${VPS_SSH_PORT:-22}"
LOCAL_CLAUDE_DIR="${LOCAL_CLAUDE_DIR:-$HOME/.claude}"

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

require_host() {
  if [[ -z "${VPS_HOST:-}" ]]; then
    echo "エラー: VPS_HOST を指定してください (例: VPS_HOST=user@example.com)" >&2
    exit 1
  fi
}

# $1=src $2=dest (どちらも末尾 / 付きディレクトリ、片方が host:path でも可)
copy_dir() {
  local src="$1" dest="$2"
  if command -v rsync >/dev/null 2>&1; then
    rsync -az --exclude '.gitkeep' -e "ssh -p $VPS_SSH_PORT" "$src" "$dest"
  else
    # rsync が無い環境 (Git Bash など) は scp で代用
    scp -r -P "$VPS_SSH_PORT" "${src%/}/." "${dest%/}/"
  fi
}

remote_has_dir() {
  ssh -p "$VPS_SSH_PORT" "$VPS_HOST" "test -d $VPS_CLAUDE_DIR/$1"
}

pull_to() {
  local dest_root="$1"
  require_host
  for kind in "${KINDS[@]}"; do
    if remote_has_dir "$kind"; then
      mkdir -p "$dest_root/$kind"
      echo "取得: $VPS_HOST:$VPS_CLAUDE_DIR/$kind -> $dest_root/$kind"
      copy_dir "$VPS_HOST:$VPS_CLAUDE_DIR/$kind/" "$dest_root/$kind/"
    else
      echo "スキップ: VPS に $VPS_CLAUDE_DIR/$kind がありません"
    fi
  done
}

cmd_install() {
  for kind in "${KINDS[@]}"; do
    [[ -d "$REPO_CLAUDE_DIR/$kind" ]] || continue
    mkdir -p "$LOCAL_CLAUDE_DIR/$kind"
    for item in "$REPO_CLAUDE_DIR/$kind"/*; do
      [[ -e "$item" ]] || continue
      echo "インストール: $item -> $LOCAL_CLAUDE_DIR/$kind/"
      cp -R "$item" "$LOCAL_CLAUDE_DIR/$kind/"
    done
  done
}

cmd_push() {
  require_host
  for kind in "${KINDS[@]}"; do
    [[ -d "$REPO_CLAUDE_DIR/$kind" ]] || continue
    ssh -p "$VPS_SSH_PORT" "$VPS_HOST" "mkdir -p $VPS_CLAUDE_DIR/$kind"
    echo "送信: $REPO_CLAUDE_DIR/$kind -> $VPS_HOST:$VPS_CLAUDE_DIR/$kind"
    copy_dir "$REPO_CLAUDE_DIR/$kind/" "$VPS_HOST:$VPS_CLAUDE_DIR/$kind/"
  done
}

case "${1:-}" in
  pull)    pull_to "$REPO_CLAUDE_DIR"; echo "完了。git add .claude && git commit で共有できます" ;;
  install) cmd_install; echo "完了。Claude Code を再起動すると反映されます" ;;
  direct)  pull_to "$LOCAL_CLAUDE_DIR"; echo "完了。Claude Code を再起動すると反映されます" ;;
  push)    cmd_push ;;
  *)       usage ;;
esac
