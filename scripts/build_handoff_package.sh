#!/usr/bin/env bash
# ==============================================================================
#  아이맥 M1 인계 패키지 빌더
#
#  bundle/ + scripts/ + docs/ 에서 인계에 필요한 파일만 모아
#  packages/lets-imac-m1-handoff.tar.gz 로 묶고 sha256 을 남깁니다.
#
#  사용: bash scripts/build_handoff_package.sh
#  주의: 시크릿·env 파일은 절대 넣지 않습니다(경로 목록만).
# ==============================================================================
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
OUT_DIR="$BASE_DIR/packages"
NAME="lets-imac-m1-handoff"
STAGE="$OUT_DIR/.stage/$NAME"

cd "$BASE_DIR" || exit 1
rm -rf "$OUT_DIR/.stage"
mkdir -p "$STAGE/bundle" "$STAGE/scripts" "$STAGE/docs"

copy() { [ -f "$1" ] && cp "$1" "$2" && echo "  + $1"; }
copy_dir() { [ -d "$1" ] && cp -R "$1" "$2" && echo "  + $1/"; }

echo "[1/4] 파일 수집"
copy_dir bundle/launchagents "$STAGE/bundle/"
copy bundle/manifest.json "$STAGE/bundle/"
copy bundle/repos.tsv "$STAGE/bundle/"
copy bundle/local_dirs.tsv "$STAGE/bundle/"
copy bundle/ollama_models.txt "$STAGE/bundle/"
copy bundle/crontab.bak "$STAGE/bundle/"
copy bundle/one_click_restore.command "$STAGE/bundle/"
copy bundle/restore_on_new_pc.sh "$STAGE/bundle/"
copy scripts/migrate_to_imac_m1.sh "$STAGE/scripts/"
copy scripts/sync_local_runtimes.sh "$STAGE/scripts/"
copy scripts/ecosystem_handoff_bundle.sh "$STAGE/scripts/"
copy docs/IMAC_M1_HANDOFF.md "$STAGE/docs/"
copy docs/MIGRATION_M2_TO_M1_IMAC.md "$STAGE/docs/"

echo "[2/4] 안내문"
BUILT_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"
{
  echo "# 아이맥 M1 인계 패키지"
  echo ""
  echo "- 빌드: $BUILT_AT"
  echo "- 출처: https://github.com/pyw31337/lets"
  echo "- 구성: launchd plist 13개 · 이전/복원 스크립트 · 런북"
  echo "- 시크릿 값은 포함하지 않습니다. 이름 목록은 docs/IMAC_M1_HANDOFF.md 참고."
  echo ""
  echo "## 아이맥에서"
  echo '```bash'
  echo "tar -xzf $NAME.tar.gz -C ~/Developer"
  echo "cd ~/Developer/$NAME && bash scripts/migrate_to_imac_m1.sh import --ssd /Volumes/IMAC_MIGRATION"
  echo '```'
  echo ""
  echo "## 맥미니에서 (번들을 새로 만들 때)"
  echo '```bash'
  echo "bash scripts/migrate_to_imac_m1.sh export --ssd /Volumes/IMAC_MIGRATION"
  echo '```'
} > "$STAGE/PACKAGE.md"

echo "[3/4] 압축"
mkdir -p "$OUT_DIR"
if tar --version 2>/dev/null | grep -q GNU; then
  tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='UTC 2026-11-26' \
      -czf "$OUT_DIR/$NAME.tar.gz" -C "$OUT_DIR/.stage" "$NAME"
else
  tar -czf "$OUT_DIR/$NAME.tar.gz" -C "$OUT_DIR/.stage" "$NAME"
fi
rm -rf "$OUT_DIR/.stage"

echo "[4/4] 체크섬"
if command -v sha256sum >/dev/null 2>&1; then
  SHA="$(sha256sum "$OUT_DIR/$NAME.tar.gz" | cut -d' ' -f1)"
else
  SHA="$(shasum -a 256 "$OUT_DIR/$NAME.tar.gz" | cut -d' ' -f1)"
fi
printf '%s  %s\n' "$SHA" "$NAME.tar.gz" > "$OUT_DIR/$NAME.sha256"
SIZE="$(du -h "$OUT_DIR/$NAME.tar.gz" | cut -f1)"
{
  echo "# lets-imac-m1-handoff"
  echo ""
  echo "- 빌드: $BUILT_AT"
  echo "- 크기: $SIZE"
  echo "- sha256: \`$SHA\`"
  echo ""
  echo "launchd 재등록 패키지입니다. 값(시크릿)은 들어 있지 않습니다."
} > "$OUT_DIR/README.md"

echo ""
echo "완료: packages/$NAME.tar.gz"
echo "sha256: $SHA"
