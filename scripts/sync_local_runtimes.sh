#!/usr/bin/env bash
# ==============================================================================
# Let's Master Ecosystem - Large Local Runtime Sync (M2 Mac mini <-> SSD / M1 iMac)
# Git에 포함되지 않은 대용량 로컬 런타임(newsboard-local, .letscamp 등)을
# 외장 SSD 또는 LAN(SSH)으로 안전하게 복사합니다.
# ==============================================================================

set -euo pipefail

MODE="${1:-}"
TARGET="${2:-}"

if [ -z "$MODE" ] || [ -z "$TARGET" ] || [[ "$MODE" != "export" && "$MODE" != "import" ]]; then
  echo "Usage:"
  echo "  1) 회사 M2 맥미니 -> 외장SSD/백업폴더로 내보내기:"
  echo "     $0 export /Volumes/MySSD/lets_runtimes"
  echo "  2) 외장SSD/백업폴더 -> 집 M1 아이맥($HOME)으로 가져오기:"
  echo "     $0 import /Volumes/MySSD/lets_runtimes"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
LOCAL_DIRS_TSV="$BASE_DIR/bundle/local_dirs.tsv"

if [ ! -f "$LOCAL_DIRS_TSV" ]; then
  echo "bundle/local_dirs.tsv가 없습니다. 먼저 ./scripts/ecosystem_handoff_bundle.sh 를 실행하세요."
  exit 1
fi

mkdir -p "$TARGET"
while IFS=$'\t' read -r rel_dir sz; do
  [ -z "$rel_dir" ] && continue
  if [ "$MODE" = "export" ]; then
    src="$HOME/$rel_dir"
    dst="$TARGET/$rel_dir"
  else
    src="$TARGET/$rel_dir"
    dst="$HOME/$rel_dir"
  fi
  if [ -d "$src" ]; then
    echo ">>> [$MODE] $rel_dir ($sz) : $src -> $dst"
    mkdir -p "$(dirname "$dst")"
    rsync -ah --delete "$src/" "$dst/"
  else
    echo ">>> [SKIP] 없음: $src"
  fi
done < "$LOCAL_DIRS_TSV"

echo "✓ 런타임 동기화($MODE) 완료!"
