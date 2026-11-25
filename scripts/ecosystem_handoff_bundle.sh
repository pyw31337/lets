#!/usr/bin/env bash
# ==============================================================================
# Let's Master Ecosystem - Automated Backup & Migration Pack Generator
# 용도: 회사 Mac mini (M2) -> 집 iMac (M1) 등 신규 Mac으로 무인 워크플로우 일괄 이관
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(dirname "$BASE_DIR")}"
BUNDLE_DIR="$BASE_DIR/bundle"
PLIST_EXPORT_DIR="$BUNDLE_DIR/launchagents"
ENV_BACKUP_DIR="$BUNDLE_DIR/env_backup"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Let's 생태계 PC 이관 번들 생성기 (M2 Mac mini -> M1 iMac)    ${NC}"
echo -e "${BLUE}================================================================${NC}"

mkdir -p "$PLIST_EXPORT_DIR" "$ENV_BACKUP_DIR"

# 1. 모든 생태계 LaunchAgents plist 자동 탐색 및 백업
echo -e "${YELLOW}[1/6] LaunchAgents plist 전체 탐색 및 추출 중...${NC}"
rm -f "$PLIST_EXPORT_DIR"/*.plist
COPIED_COUNT=0
copy_plist() {
  local src="$1"
  local base
  base=$(basename "$src")
  if [ -f "$src" ] && [ ! -f "$PLIST_EXPORT_DIR/$base" ]; then
    cp "$src" "$PLIST_EXPORT_DIR/$base"
    echo "  - 백업 완료: $base"
    COPIED_COUNT=$((COPIED_COUNT + 1))
  fi
}

if [ -d "$HOME/Library/LaunchAgents" ]; then
  while IFS= read -r -d '' found_plist; do
    copy_plist "$found_plist"
  done < <(find "$HOME/Library/LaunchAgents" -maxdepth 1 -type f \( \
    -name "com.pyw31337.*.plist" -o \
    -name "com.lets*.plist" -o \
    -name "com.moyeora.*.plist" -o \
    -name "com.cultureflow.*.plist" -o \
    -name "com.limery.*.plist" \
  \) -print0 2>/dev/null || true)
fi
echo "  => 총 ${COPIED_COUNT}개 LaunchAgent 백업"

# 2. Crontab 백업
echo -e "${YELLOW}[2/6] 사용자 crontab 백업 중...${NC}"
if crontab -l > "$BUNDLE_DIR/crontab.bak" 2>/dev/null; then
  echo "  - crontab.bak 저장 완료 ($(wc -l < "$BUNDLE_DIR/crontab.bak" | tr -d ' ')줄)"
else
  : > "$BUNDLE_DIR/crontab.bak"
  echo "  - 등록된 crontab 없음 (빈 파일 생성)"
fi

# 3. Ollama 모델 인벤토리 수집
echo -e "${YELLOW}[3/6] Ollama 모델 인벤토리 수집 중...${NC}"
OLLAMA_LIST_FILE="$BUNDLE_DIR/ollama_models.txt"
if command -v ollama >/dev/null 2>&1 && ollama list >/dev/null 2>&1; then
  ollama list | awk 'NR>1 && $1 != "" {print $1}' > "$OLLAMA_LIST_FILE"
else
  printf "qwen2.5vl:3b\nllama3.2:1b\nqwen2.5:3b\nllama3.2:3b\n" > "$OLLAMA_LIST_FILE"
fi
echo "  - Ollama 모델 목록: $(tr '\n' ' ' < "$OLLAMA_LIST_FILE")"

# 4. Git 저장소 목록(repos.tsv) & 비-Git 런타임 디렉토리 목록(local_dirs.tsv) 수집
echo -e "${YELLOW}[4/6] Git 저장소 및 로컬 런타임 디렉토리 인벤토리 수집 중...${NC}"
REPOS_TSV="$BUNDLE_DIR/repos.tsv"
: > "$REPOS_TSV"
for dir in "$WORKSPACE_ROOT"/*; do
  if [ -d "$dir/.git" ]; then
    repo_name=$(basename "$dir")
    remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null || echo "")
    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    if [ -n "$remote_url" ]; then
      printf "%s\t%s\t%s\n" "$repo_name" "$remote_url" "$branch" >> "$REPOS_TSV"
    fi
  fi
done
echo "  - Git 저장소 $(wc -l < "$REPOS_TSV" | tr -d ' ')개 기록 (repos.tsv)"

LOCAL_DIRS_TSV="$BUNDLE_DIR/local_dirs.tsv"
: > "$LOCAL_DIRS_TSV"
RUNTIME_CANDIDATES=(
  "$HOME/.letscamp"
  "$HOME/.cctv-ops"
  "$HOME/Library/Application Support/Limery"
  "$HOME/Library/Application Support/Moyeora"
  "$WORKSPACE_ROOT/newsboard-local"
  "$WORKSPACE_ROOT/news"
  "$WORKSPACE_ROOT/family_os_web"
)
for rdir in "${RUNTIME_CANDIDATES[@]}"; do
  if [ -d "$rdir" ]; then
    rel="${rdir#"$HOME/"}"
    sz=$(du -sh "$rdir" 2>/dev/null | awk '{print $1}')
    printf "%s\t%s\n" "$rel" "$sz" >> "$LOCAL_DIRS_TSV"
    echo "  - 비-Git 런타임 감지: ~/$rel ($sz)"
  fi
done

# 5. 로컬 .env / 설정 백업 (아카이브 전용; git 커밋 제외)
echo -e "${YELLOW}[5/6] 로컬 환경변수(.env) 및 핵심 설정 백업 중...${NC}"
rm -rf "$ENV_BACKUP_DIR"/*
ENV_COUNT=0
while IFS=$'\t' read -r repo_name _ _; do
  for env_rel in ".env" ".env.local" "config/alert.env"; do
    env_src="$WORKSPACE_ROOT/$repo_name/$env_rel"
    if [ -f "$env_src" ]; then
      mkdir -p "$ENV_BACKUP_DIR/workspace/$repo_name/$(dirname "$env_rel")"
      cp "$env_src" "$ENV_BACKUP_DIR/workspace/$repo_name/$env_rel"
      ENV_COUNT=$((ENV_COUNT + 1))
    fi
  done
done < "$REPOS_TSV"

for home_cfg in ".letscamp/env" "Library/Application Support/Moyeora/media-worker.json"; do
  if [ -f "$HOME/$home_cfg" ]; then
    mkdir -p "$ENV_BACKUP_DIR/_home_/$(dirname "$home_cfg")"
    cp "$HOME/$home_cfg" "$ENV_BACKUP_DIR/_home_/$home_cfg"
    ENV_COUNT=$((ENV_COUNT + 1))
  fi
done
echo "  - 환경변수/설정 파일 ${ENV_COUNT}개 백업"

# 6. manifest.json 기록 및 원클릭 아카이브 패키징
echo -e "${YELLOW}[6/6] manifest.json 생성 및 tar.gz 패키징...${NC}"
CHIP_NAME="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
RAM_GB=$(( RAM_BYTES / 1024 / 1024 / 1024 ))

cat <<EOF > "$BUNDLE_DIR/manifest.json"
{
  "bundle_version": "2.1.0",
  "exported_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source_machine": {
    "hostname": "$(hostname)",
    "user": "$USER",
    "home": "$HOME",
    "workspace_root": "$WORKSPACE_ROOT",
    "os": "$(uname -s)",
    "arch": "$(uname -m)",
    "chip": "$CHIP_NAME",
    "ram_gb": $RAM_GB
  },
  "ollama_models_file": "bundle/ollama_models.txt",
  "repos_inventory": "bundle/repos.tsv",
  "local_dirs_inventory": "bundle/local_dirs.tsv",
  "launchagents_count": $COPIED_COUNT,
  "env_files_count": $ENV_COUNT,
  "zero_cloud_cost": true
}
EOF

cp "$SCRIPT_DIR/restore_on_new_pc.sh" "$BUNDLE_DIR/"
cp "$SCRIPT_DIR/one_click_restore.command" "$BUNDLE_DIR/"
chmod +x "$BUNDLE_DIR/restore_on_new_pc.sh" "$BUNDLE_DIR/one_click_restore.command"

ARCHIVE_PATH="$BUNDLE_DIR/lets_ecosystem_handoff_pack.tar.gz"
tar -czf "$ARCHIVE_PATH" -C "$BASE_DIR" \
  bundle/launchagents \
  bundle/env_backup \
  bundle/manifest.json \
  bundle/ollama_models.txt \
  bundle/repos.tsv \
  bundle/local_dirs.tsv \
  bundle/crontab.bak \
  bundle/one_click_restore.command \
  scripts/restore_on_new_pc.sh \
  scripts/one_click_restore.command \
  scripts/sync_local_runtimes.sh

echo ""
echo -e "${GREEN}✓ PC 무중단 이관 번들 생성 완료!${NC}"
echo -e "  - 컨트롤 팩: $ARCHIVE_PATH ($(du -sh "$ARCHIVE_PATH" | awk '{print $1}'))"
echo -e "  - 대용량 런타임(newsboard-local 등)은 ./scripts/sync_local_runtimes.sh 로 외장SSD/LAN 동기화하세요."
echo -e "  - 신규 iMac에서 압축 해제 후 ${YELLOW}bundle/one_click_restore.command${NC} 더블클릭으로 원클릭 복원!"
