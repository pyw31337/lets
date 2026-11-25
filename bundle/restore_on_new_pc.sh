#!/usr/bin/env bash
# ==============================================================================
# Let's Master Ecosystem - New PC Migration & Automated Restore Script
# 이관 대상: 집 iMac (M1) / 신규 Mac mini / 예비 macOS 머신
# 기능: 런타임(brew/node/python/gh/ollama) 설치, M1 최적화, 저장소·런타임 복원,
#       13대 LaunchAgents 경로 치환 등록 및 실행 대상 파일 실존 검증
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DRY_RUN=0
APPLY_PMSET=0
RUNTIME_SOURCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --apply-pmset) APPLY_PMSET=1; shift ;;
    --runtime-source) RUNTIME_SOURCE="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--apply-pmset] [--runtime-source /Volumes/SSD/lets_runtimes]"
      exit 0
      ;;
    *) shift ;;
  esac
done

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
BUNDLE_DIR="$BASE_DIR/bundle"
if [ ! -d "$BUNDLE_DIR" ] && [ -d "$SCRIPT_DIR/launchagents" ]; then
  BUNDLE_DIR="$SCRIPT_DIR"
fi

TARGET_WORKSPACE="${WORKSPACE_ROOT:-$HOME/Developer}"
CHIP_NAME="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$(( RAM_BYTES / 1024 / 1024 / 1024 ))

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Let's 생태계 원클릭 PC 이관 & 자동 복원 엔진                 ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "호스트: $(hostname) ($(uname -s) $(uname -m) · $CHIP_NAME · ${RAM_GB}GB RAM)"
echo -e "대상 경로: $TARGET_WORKSPACE (HOME=$HOME)"
echo -e "모드: $([ "$DRY_RUN" -eq 1 ] && echo 'DRY-RUN(점검만)' || echo 'APPLY(실제 복원)')"
echo ""

# 1. Homebrew, Git, Python3, Node.js, gh CLI 점검 및 설치
echo -e "${YELLOW}[1/7] 필수 런타임 점검 (brew, git, python3, node, gh)...${NC}"
if ! command -v brew >/dev/null 2>&1; then
  echo -e "${RED}Homebrew가 없습니다. 먼저 설치하세요:${NC}"
  echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi
for pkg in git python3 node gh; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    echo "  - $pkg 미설치 -> brew install $pkg"
    [ "$DRY_RUN" -eq 0 ] && brew install "$pkg" || true
  fi
done
echo -e "${GREEN}✓ 런타임 확인 완료 (node: $(node -v 2>/dev/null || echo 'pending'), python3: $(python3 --version 2>/dev/null || echo 'pending'))${NC}"

# 2. M1 iMac 메모리/전원(pmset) 최적화
echo -e "${YELLOW}[2/7] M1 iMac 메모리·전원(무인 가동) 설정 점검...${NC}"
if [[ "$CHIP_NAME" == *"M1"* ]] || [ "$RAM_GB" -le 16 ]; then
  echo "  - M1 / ${RAM_GB}GB 환경 감지: Ollama 동시 모델 수를 1개로 제한해 스왑 병목을 방지합니다."
  if [ "$DRY_RUN" -eq 0 ]; then
    launchctl setenv OLLAMA_MAX_LOADED_MODELS 1 2>/dev/null || true
    launchctl setenv OLLAMA_NUM_PARALLEL 1 2>/dev/null || true
    launchctl setenv OLLAMA_KEEP_ALIVE 5m 2>/dev/null || true
    if ! grep -q "OLLAMA_MAX_LOADED_MODELS" "$HOME/.zshrc" 2>/dev/null; then
      cat <<'ZSHRC' >> "$HOME/.zshrc"

# LetsHub M1 iMac Ollama memory guard
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_KEEP_ALIVE=5m
ZSHRC
    fi
  fi
fi

CURRENT_SLEEP=$(pmset -g 2>/dev/null | awk '/^[[:space:]]*sleep[[:space:]]/{print $2}' | head -n1 || echo "?")
echo "  - 현재 시스템 sleep 설정: ${CURRENT_SLEEP} (무인 야간 수집을 위해 0 권장)"
if [ "$APPLY_PMSET" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  echo "  - iMac 무인 가동 전원 설정 적용 중 (sudo 비밀번호 입력 필요)..."
  sudo pmset -a sleep 0 disksleep 0 autorestart 1 displaysleep 10
  echo -e "${GREEN}✓ pmset 무인 가동 설정 적용 완료${NC}"
elif [ "$CURRENT_SLEEP" != "0" ]; then
  echo -e "  - 안내: 야간 배치가 멈추지 않으려면 아래 명령을 실행하세요:"
  echo -e "    ${YELLOW}sudo pmset -a sleep 0 disksleep 0 autorestart 1 displaysleep 10${NC}"
fi

# 3. Ollama 설치 및 모델 풀링
echo -e "${YELLOW}[3/7] Ollama 엔진 및 모델 확인...${NC}"
MODELS_FILE="$BUNDLE_DIR/ollama_models.txt"
[ -f "$MODELS_FILE" ] || MODELS_FILE=""
if [ "$DRY_RUN" -eq 0 ]; then
  if ! command -v ollama >/dev/null 2>&1; then
    brew install ollama
  fi
  if ! pgrep -x "ollama" >/dev/null 2>&1; then
    brew services start ollama 2>/dev/null || (ollama serve >/dev/null 2>&1 &)
    sleep 3
  fi
  if [ -n "$MODELS_FILE" ]; then
    while IFS= read -r model; do
      [ -z "$model" ] && continue
      echo "  - ollama pull $model"
      ollama pull "$model"
    done < "$MODELS_FILE"
  fi
else
  echo "  - [DRY-RUN] 모델 목록: $([ -n "$MODELS_FILE" ] && tr '\n' ' ' < "$MODELS_FILE" || echo 'default')"
fi
echo -e "${GREEN}✓ Ollama 단계 완료${NC}"

# 4. 로컬 Git 저장소 동기화
echo -e "${YELLOW}[4/7] Git 저장소 클론/확인...${NC}"
mkdir -p "$TARGET_WORKSPACE"
if [ -f "$BUNDLE_DIR/repos.tsv" ]; then
  while IFS=$'\t' read -r repo_name remote_url branch; do
    [ -z "$repo_name" ] && continue
    dest="$TARGET_WORKSPACE/$repo_name"
    if [ -d "$dest/.git" ]; then
      echo "  - 이미 존재: $repo_name"
    else
      echo "  - 클론 대상: $repo_name <- $remote_url ($branch)"
      if [ "$DRY_RUN" -eq 0 ]; then
        git clone --branch "$branch" "$remote_url" "$dest" || git clone "$remote_url" "$dest"
      fi
    fi
  done < "$BUNDLE_DIR/repos.tsv"
fi

# 5. 비-Git 런타임 디렉토리 동기화 및 .env 복원
echo -e "${YELLOW}[5/7] 로컬 런타임 데이터 및 환경변수(.env) 복원...${NC}"
if [ -n "$RUNTIME_SOURCE" ] && [ -d "$RUNTIME_SOURCE" ] && [ -f "$BUNDLE_DIR/local_dirs.tsv" ]; then
  while IFS=$'\t' read -r rel_dir sz; do
    [ -z "$rel_dir" ] && continue
    src="$RUNTIME_SOURCE/$rel_dir"
    dst="$HOME/$rel_dir"
    if [ -d "$src" ]; then
      echo "  - 런타임 복사: ~/$rel_dir ($sz)"
      if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$(dirname "$dst")"
        rsync -ah --info=progress2 "$src/" "$dst/"
      fi
    fi
  done < "$BUNDLE_DIR/local_dirs.tsv"
fi

if [ -d "$BUNDLE_DIR/env_backup/workspace" ]; then
  while IFS= read -r -d '' env_file; do
    rel="${env_file#"$BUNDLE_DIR/env_backup/workspace/"}"
    dest="$TARGET_WORKSPACE/$rel"
    echo "  - env 복원: $rel"
    if [ "$DRY_RUN" -eq 0 ]; then
      mkdir -p "$(dirname "$dest")"
      cp "$env_file" "$dest"
    fi
  done < <(find "$BUNDLE_DIR/env_backup/workspace" -type f -print0 2>/dev/null || true)
fi

if [ -d "$BUNDLE_DIR/env_backup/_home_" ]; then
  while IFS= read -r -d '' home_file; do
    rel="${home_file#"$BUNDLE_DIR/env_backup/_home_/"}"
    dest="$HOME/$rel"
    echo "  - 홈 설정 복원: ~/$rel"
    if [ "$DRY_RUN" -eq 0 ]; then
      mkdir -p "$(dirname "$dest")"
      cp "$home_file" "$dest"
    fi
  done < <(find "$BUNDLE_DIR/env_backup/_home_" -type f -print0 2>/dev/null || true)
fi

# 6. LaunchAgents 경로 치환($SOURCE_HOME -> $HOME) 및 등록
echo -e "${YELLOW}[6/7] LaunchAgents plist 경로 보정 및 등록...${NC}"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_DIR"
SOURCE_HOME=""
if [ -f "$BUNDLE_DIR/manifest.json" ]; then
  SOURCE_HOME=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('source_machine',{}).get('home',''))" "$BUNDLE_DIR/manifest.json" 2>/dev/null || echo "")
fi

BUNDLE_PLIST_DIR="$BUNDLE_DIR/launchagents"
if [ -d "$BUNDLE_PLIST_DIR" ]; then
  UID_NUM=$(id -u)
  for plist in "$BUNDLE_PLIST_DIR"/*.plist; do
    [ -f "$plist" ] || continue
    base_plist=$(basename "$plist")
    target_plist="$LAUNCH_DIR/$base_plist"
    echo "  - 등록 준비: $base_plist"
    if [ "$DRY_RUN" -eq 0 ]; then
      if [ -n "$SOURCE_HOME" ] && [ "$SOURCE_HOME" != "$HOME" ]; then
        python3 -c "
from pathlib import Path
import sys
src, dst, old_h, new_h = sys.argv[1:]
text = Path(src).read_text(encoding='utf-8')
Path(dst).write_text(text.replace(old_h, new_h), encoding='utf-8')
" "$plist" "$target_plist" "$SOURCE_HOME" "$HOME"
      else
        cp "$plist" "$target_plist"
      fi
      python3 -c "
import plistlib, sys
from pathlib import Path
with open(sys.argv[1], 'rb') as f:
    p = plistlib.load(f)
for k in ('StandardOutPath', 'StandardErrorPath', 'WorkingDirectory'):
    v = p.get(k)
    if v:
        path = Path(v) if k == 'WorkingDirectory' else Path(v).parent
        path.mkdir(parents=True, exist_ok=True)
" "$target_plist" 2>/dev/null || true
      launchctl bootout "gui/$UID_NUM" "$target_plist" 2>/dev/null || launchctl unload "$target_plist" 2>/dev/null || true
      launchctl bootstrap "gui/$UID_NUM" "$target_plist" 2>/dev/null || launchctl load -w "$target_plist"
    fi
  done
fi

# 7. 모든 자동화 장치 실행 경로 실존 검증
echo -e "${YELLOW}[7/7] 전체 LaunchAgents 실행 경로 검증...${NC}"
MISSING_TARGETS=0
for plist in "$BUNDLE_PLIST_DIR"/*.plist; do
  [ -f "$plist" ] || continue
  status_line=$(python3 -c "
import plistlib, os, sys
with open(sys.argv[1], 'rb') as f:
    d = plistlib.load(f)
old_h, new_h = sys.argv[2], sys.argv[3]
args = d.get('ProgramArguments') or [d.get('Program')]
target = None
for a in args:
    if isinstance(a, str) and (a.endswith('.sh') or a.endswith('.py') or a.endswith('.mjs')):
        target = a.replace(old_h, new_h) if old_h else a
        break
if not target and args:
    target = str(args[0]).replace(old_h, new_h) if old_h else str(args[0])
exists = os.path.exists(target) if target else False
print(f'{\"OK\" if exists else \"MISSING\"}\t{os.path.basename(sys.argv[1])}\t{target}')
" "$plist" "$SOURCE_HOME" "$HOME" 2>/dev/null || echo "ERR	$(basename "$plist")	unknown")
  tag=$(echo "$status_line" | cut -f1)
  pname=$(echo "$status_line" | cut -f2)
  ptarget=$(echo "$status_line" | cut -f3)
  if [ "$tag" = "OK" ]; then
    echo -e "  ${GREEN}[OK]${NC} $pname -> $ptarget"
  else
    echo -e "  ${RED}[MISSING]${NC} $pname -> $ptarget"
    MISSING_TARGETS=$((MISSING_TARGETS + 1))
  fi
done

if [ "$MISSING_TARGETS" -gt 0 ]; then
  echo -e "${YELLOW}! 누락된 런타임 경로가 ${MISSING_TARGETS}개 있습니다. sync_local_runtimes.sh 로 대용량 런타임을 동기화한 뒤 다시 실행하세요.${NC}"
fi

if [ "$DRY_RUN" -eq 0 ] && [ -f "$BASE_DIR/scripts/audit_truth_contract.py" ]; then
  python3 "$BASE_DIR/scripts/audit_truth_contract.py" || true
fi

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  ✓ M1 iMac 이관 복원 절차 완료!                               ${NC}"
echo -e "${GREEN}  - 관제 허브: https://pyw31337.github.io/lets/                 ${NC}"
echo -e "${GREEN}================================================================${NC}"
