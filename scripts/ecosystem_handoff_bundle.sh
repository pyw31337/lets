#!/usr/bin/env bash
# ==============================================================================
# Let's Master Ecosystem - Automated Backup & Migration Pack Generator
# 기능: 현재 머신(회사 PC)의 무인 수집기 설정 및 plist, Ollama 인벤토리를 1개로 패키징
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$SCRIPT_DIR/.."
BUNDLE_DIR="$BASE_DIR/bundle"
PLIST_EXPORT_DIR="$BUNDLE_DIR/launchagents"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Let's 생태계 무중단 PC 이관 번들 생성기                        ${NC}"
echo -e "${BLUE}================================================================${NC}"

mkdir -p "$PLIST_EXPORT_DIR"

# 1. 9대 생태계 LaunchAgents plist 백업
echo -e "${YELLOW}[1/3] 생태계 9대 LaunchAgents plist 추출 중...${NC}"
PLISTS=(
  "com.letscamp.nightshift.plist"
  "com.moyeora.culture-intelligence.plist"
  "com.pyw31337.letsview.playback-addresses.plist"
  "com.pyw31337.newsboard-ai.plist"
  "com.pyw31337.newsboard-analyze.plist"
  "com.pyw31337.newsboard-dispatch.plist"
  "com.pyw31337.newsboard-gov.plist"
  "com.pyw31337.newsboard-journalists.plist"
  "com.pyw31337.newsboard-pol.plist"
)

COPIED_COUNT=0
for plist in "${PLISTS[@]}"; do
  SRC="$HOME/Library/LaunchAgents/$plist"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$PLIST_EXPORT_DIR/"
    echo "  - 백업 완료: $plist"
    COPIED_COUNT=$((COPIED_COUNT + 1))
  else
    echo "  - [주의] 미발견: $plist"
  fi
done

# 2. Ollama 모델 인벤토리 및 시스템 매니페스트 생성
echo -e "${YELLOW}[2/3] 시스템 환경 및 모델 매니페스트(manifest.json) 기록...${NC}"
cat <<EOF > "$BUNDLE_DIR/manifest.json"
{
  "bundle_version": "1.0.0",
  "exported_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source_machine": {
    "hostname": "$(hostname)",
    "os": "$(uname -s)",
    "arch": "$(uname -m)"
  },
  "ollama_models": [
    {
      "model": "qwen2.5vl:3b",
      "size": "3.2GB",
      "service": "렛츠캠프 야간 비전 OCR 판독"
    },
    {
      "model": "llama3.2:1b",
      "size": "1.3GB",
      "service": "컬처플로우 심야 문화 인텔리전스"
    }
  ],
  "launchagents_count": $COPIED_COUNT,
  "ecosystem_services": 15,
  "automation_devices": 61,
  "zero_cloud_cost": true
}
EOF

# 3. 복원 스크립트 번들 포함 및 tar.gz 압축
echo -e "${YELLOW}[3/3] 원클릭 이관 아카이브 패키징...${NC}"
cp "$SCRIPT_DIR/restore_on_new_pc.sh" "$BUNDLE_DIR/"
chmod +x "$BUNDLE_DIR/restore_on_new_pc.sh"

ARCHIVE_PATH="$BUNDLE_DIR/lets_ecosystem_handoff_pack.tar.gz"
tar -czf "$ARCHIVE_PATH" -C "$BASE_DIR" bundle/launchagents bundle/manifest.json scripts/restore_on_new_pc.sh

echo ""
echo -e "${GREEN}✓ PC 무중단 이관 번들 생성 완료!${NC}"
echo -e "  - 아카이브 위치: $ARCHIVE_PATH"
echo -e "  - 매니페스트: $BUNDLE_DIR/manifest.json"
echo -e "  - 신규 머신 복원 명령어:"
echo -e "    ${YELLOW}tar -xzf lets_ecosystem_handoff_pack.tar.gz && ./scripts/restore_on_new_pc.sh${NC}"
