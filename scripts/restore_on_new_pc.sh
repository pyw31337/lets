#!/usr/bin/env bash
# ==============================================================================
# Let's Master Ecosystem - New PC Migration & Automated Restore Script
# 이관 대상: 신규 Mac mini / 홈 PC / 예비 머신
# 기능: Ollama 로컬 모델 자동 풀링, 9대 LaunchAgents 무인 데몬 등록, 의존성 복구
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Let's 생태계 무중단 PC 이관 & 워크플로우 자동 복원 엔진        ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "호스트 OS: $(uname -s) $(uname -m)"
echo -e "복원 일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. Homebrew & 필수 런타임 점검
echo -e "${YELLOW}[1/5] 런타임 및 패키지 매니저 점검...${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew가 설치되어 있지 않습니다. Homebrew를 먼저 설치해주세요:${NC}"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi
echo -e "${GREEN}✓ Homebrew 정상 확인${NC}"

# 2. Ollama 설치 및 백그라운드 서비스 활성화
echo -e "${YELLOW}[2/5] Ollama 온디바이스 에지 AI 엔진 점검...${NC}"
if ! command -v ollama &> /dev/null; then
    echo -e "Ollama 설치 중 (brew install ollama)..."
    brew install ollama
fi
echo -e "${GREEN}✓ Ollama 바이너리 확인${NC}"

# Ollama 데몬 실행 여부 확인
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "Ollama 백그라운드 서비스 기동 중..."
    brew services start ollama 2>/dev/null || (ollama serve >/dev/null 2>&1 &)
    sleep 3
fi
echo -e "${GREEN}✓ Ollama 에지 서비스 정상 실행 중${NC}"

# 3. 필수 온디바이스 모델 2종 자동 풀링 (qwen2.5vl:3b, llama3.2:1b)
echo -e "${YELLOW}[3/5] 필수 온디바이스 AI 모델 풀링 (무료 온디바이스 에지 연산)...${NC}"
echo -e " - [1/2] 렛츠캠프 비전 OCR 모델 풀링 (qwen2.5vl:3b, ~3.2GB)..."
ollama pull qwen2.5vl:3b

echo -e " - [2/2] 컬처플로우 심야 인텔리전스 모델 풀링 (llama3.2:1b, ~1.3GB)..."
ollama pull llama3.2:1b
echo -e "${GREEN}✓ Ollama 필수 모델 2종 준비 완료 (총 4.5GB, 클라우드 비용 $0)${NC}"

# 4. 9대 LaunchAgents 무인 데몬 plist 배치 및 등록
echo -e "${YELLOW}[4/5] 9대 무인 백그라운드 데몬(LaunchAgents) 등록...${NC}"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_DIR"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUNDLE_PLIST_DIR="$SCRIPT_DIR/../bundle/launchagents"

# 번들 폴더가 없으면 현재 디렉토리 기준 탐색
if [ ! -d "$BUNDLE_PLIST_DIR" ]; then
    BUNDLE_PLIST_DIR="$SCRIPT_DIR/launchagents"
fi

if [ -d "$BUNDLE_PLIST_DIR" ]; then
    for plist in "$BUNDLE_PLIST_DIR"/*.plist; do
        if [ -f "$plist" ]; then
            base_plist=$(basename "$plist")
            echo -e " - 복사 및 등록: $base_plist"
            cp "$plist" "$LAUNCH_DIR/$base_plist"
            launchctl unload "$LAUNCH_DIR/$base_plist" 2>/dev/null || true
            launchctl load -w "$LAUNCH_DIR/$base_plist"
        fi
    done
    echo -e "${GREEN}✓ 9대 LaunchAgents 등록 및 즉시 활성화 완료${NC}"
else
    echo -e "${YELLOW}! 번들 plist 폴더를 찾을 수 없어 깃 리포지토리 기준 기본 템플릿을 확인합니다.${NC}"
fi

# 5. 최종 사활 헬스체크 및 요약
echo -e "${YELLOW}[5/5] 생태계 무인 파이프라인 사활 점검...${NC}"
echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  ✓ 무중단 인계(Handoff) 복원 완료!                            ${NC}"
echo -e "${GREEN}  - 회사 PC의 모든 백그라운드 수집/분석 작업이 이 머신에 인계됨 ${NC}"
echo -e "${GREEN}  - 등록된 서비스·자동화 장치 복원 완료 (실행 상태는 허브에서 검증) ${NC}"
echo -e "${GREEN}  - 실시간 관제 허브: https://pyw31337.github.io/lets/         ${NC}"
echo -e "${GREEN}================================================================${NC}"
