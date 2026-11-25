#!/usr/bin/env bash
# ==============================================================================
# Let's Master Ecosystem - One-Click macOS Double-Clickable Restore Launcher
# Finder에서 더블클릭하면 터미널에서 자동으로 복원 엔진을 실행합니다.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$SCRIPT_DIR/restore_on_new_pc.sh" ]; then
  RESTORE_SH="$SCRIPT_DIR/restore_on_new_pc.sh"
elif [ -f "$SCRIPT_DIR/../scripts/restore_on_new_pc.sh" ]; then
  RESTORE_SH="$SCRIPT_DIR/../scripts/restore_on_new_pc.sh"
else
  echo "restore_on_new_pc.sh를 찾을 수 없습니다."
  read -r -p "엔터를 누르면 종료합니다..."
  exit 1
fi

echo "Let's 생태계 원클릭 복원을 시작합니다..."
"$RESTORE_SH" --apply-pmset "$@"
echo ""
read -r -p "작업이 완료되었습니다. 창을 닫으려면 엔터를 누르세요..."
