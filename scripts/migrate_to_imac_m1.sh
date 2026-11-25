#!/usr/bin/env bash
# ==============================================================================
#  Let's 인계 엔진 — 회사 Mac mini(M2) → 집 iMac(M1)
#
#  한 파일로 양쪽 기기에서 씁니다.
#    맥미니:  bash scripts/migrate_to_imac_m1.sh export --ssd /Volumes/IMAC_MIGRATION
#    아이맥:  bash scripts/migrate_to_imac_m1.sh import --ssd /Volumes/IMAC_MIGRATION
#             bash scripts/migrate_to_imac_m1.sh verify
#    맥미니:  bash scripts/migrate_to_imac_m1.sh retire --yes
#
#  원칙
#   - 시크릿 값은 읽지도, 쓰지도, 출력하지도 않습니다. 이름만 다룹니다.
#   - 기존 파일을 지우지 않습니다. 옮길 때는 ~/.migrated_trash/ 로 이동합니다.
#   - 실패한 작업은 건너뛰고 마지막에 목록으로 보고합니다(전체 중단 없음).
# ==============================================================================

# macOS 기본 bash 3.2 에서도 안전하도록 set -u 는 쓰지 않습니다.
set -o pipefail

VERSION="1.0.0"
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
BUNDLE_DIR="$BASE_DIR/bundle"
LIVE_DIR="$BUNDLE_DIR/live"
MANIFEST="$BUNDLE_DIR/manifest.json"
REPOS_TSV="$BUNDLE_DIR/repos.tsv"
DIRS_TSV="$BUNDLE_DIR/local_dirs.tsv"
PLIST_DIR="$BUNDLE_DIR/launchagents"
SECRET_KEYS_FILE="$LIVE_DIR/secret-keys-only.txt"

WORKSPACE="${WORKSPACE_ROOT:-$HOME/Developer}"
SSD=""
DRY_RUN=0
YES=0
APPLY_PMSET=0
FINAL=0
CMD="${1:-plan}"
[ $# -gt 0 ] && shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    --ssd) SSD="${2:-}"; shift 2 ;;
    --workspace) WORKSPACE="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) YES=1; shift ;;
    --apply-pmset) APPLY_PMSET=1; shift ;;
    --final) FINAL=1; shift ;;
    -h|--help) CMD="help"; shift ;;
    *) echo "알 수 없는 옵션: $1"; CMD="help"; shift ;;
  esac
done

FAILED=()
SKIPPED=()
note()  { printf '  %b%s%b\n' "$DIM" "$*" "$NC"; }
ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
miss()  { printf '  \033[0;31m×\033[0m %s\n' "$*"; }
step()  { printf '\n\033[0;34m[%s]\033[0m \033[1m%s\033[0m\n' "$1" "$2"; }
head_() {
  printf '\033[0;34m================================================================\033[0m\n'
  printf '  Let’s 인계 엔진 v%s — %s\n' "$VERSION" "$1"
  printf '  %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf '\033[0;34m================================================================\033[0m\n'
}
have() { command -v "$1" >/dev/null 2>&1; }
is_mac() { [ "$(uname -s)" = "Darwin" ]; }
py() { if have python3; then python3 "$@"; else return 1; fi; }

source_home() {
  if [ -f "$MANIFEST" ] && have python3; then
    python3 - "$MANIFEST" <<'PY' 2>/dev/null || echo "/Users/pyw31337"
import json,sys
print(json.load(open(sys.argv[1])).get('source_machine',{}).get('home','/Users/pyw31337'))
PY
  else
    echo "/Users/pyw31337"
  fi
}

# ------------------------------------------------------------------------------
# plan
# ------------------------------------------------------------------------------
cmd_plan() {
  head_ "인계 계획"
  local host chip ram
  host="$(hostname 2>/dev/null || echo unknown)"
  if is_mac; then
    chip="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
    ram="$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))GB"
  else
    chip="$(uname -m)"; ram="?"
  fi
  echo "현재 기기: $host · $(uname -s) · $chip · $ram"
  echo "작업 경로: $WORKSPACE"
  echo "번들 기준: $(py - "$MANIFEST" <<'PY' 2>/dev/null || echo 'manifest 없음'
import json,sys
d=json.load(open(sys.argv[1]))
s=d.get('source_machine',{})
print(f"{s.get('hostname','?')} · {s.get('chip','?')} · {s.get('ram_gb','?')}GB · exported_at {d.get('exported_at','?')}")
PY
)"
  echo ""
  echo "맥미니에서 (마지막 근무일 전까지)"
  echo "  1. bash scripts/migrate_to_imac_m1.sh export --ssd /Volumes/IMAC_MIGRATION"
  echo "  2. zsh ~/Developer/calendar/tools/mac-automation/backup.sh --with-secrets"
  echo ""
  echo "아이맥에서"
  echo "  3. bash scripts/migrate_to_imac_m1.sh import --ssd /Volumes/IMAC_MIGRATION --apply-pmset"
  echo "  4. bash scripts/migrate_to_imac_m1.sh secrets     # 값은 직접 입력"
  echo "  5. bash scripts/migrate_to_imac_m1.sh verify"
  echo ""
  echo "아이맥 첫 성공 확인 뒤 맥미니에서"
  echo "  6. bash scripts/migrate_to_imac_m1.sh retire --yes"
  echo ""
  echo "등록 대상 launchd: $(ls "$PLIST_DIR"/*.plist 2>/dev/null | wc -l | tr -d ' ')개  ·  복사할 런타임: $(wc -l < "$DIRS_TSV" 2>/dev/null | tr -d ' ')개"
}

# ------------------------------------------------------------------------------
# export  (맥미니에서 실행)
# ------------------------------------------------------------------------------
cmd_export() {
  head_ "맥미니 → 인계 번들 내보내기"
  if ! is_mac; then
    miss "macOS에서만 실행할 수 있습니다. (현재 $(uname -s))"
    echo "  집 아이맥으로 옮길 자료는 맥미니 터미널에서 이 명령을 실행해야 만들어집니다." >&2
    return 2
  fi
  mkdir -p "$LIVE_DIR" "$PLIST_DIR"

  step 1/8 "launchd 전체 재스캔 (접두사 제한 없이)"
  local all_tsv="$LIVE_DIR/launchagents-all.tsv"
  : > "$all_tsv"
  local count=0 p labels label
  for p in "$HOME/Library/LaunchAgents"/*.plist; do
    [ -f "$p" ] || continue
    label="$(basename "$p" .plist)"
    case "$label" in com.apple.*) continue ;; esac
    count=$((count + 1))
    if have python3; then
      python3 - "$p" <<'PY' 2>/dev/null >> "$all_tsv" || printf '%s\t?\t?\t?\n' "$label" >> "$all_tsv"
import plistlib, sys
d = plistlib.load(open(sys.argv[1], 'rb'))
args = d.get('ProgramArguments') or [d.get('Program') or '']
target = next((a for a in args if isinstance(a, str) and (a.endswith('.sh') or a.endswith('.py') or a.endswith('.mjs') or a.endswith('.command'))), '')
sched = []
cal = d.get('StartCalendarInterval')
if isinstance(cal, dict): cal = [cal]
for c in cal or []:
    sched.append(':'.join(str(c.get(k, '*')) for k in ('Hour', 'Minute')))
if d.get('StartInterval'): sched.append(f"every {d['StartInterval']}s")
if d.get('RunAtLoad'): sched.append('RunAtLoad')
print('\t'.join([d.get('Label', '?'), target or '-', ','.join(sched) or '-', (d.get('WorkingDirectory') or '-')]))
PY
    else
      printf '%s\t-\t-\t-\n' "$label" >> "$all_tsv"
    fi
  done
  echo "  사용자 LaunchAgent 후보 ${count}개 → $all_tsv"
  if have launchctl; then
    launchctl list 2>/dev/null | grep -v '^\s*-\s*0\s*com.apple' | awk 'NF>=3' > "$LIVE_DIR/launchctl-list.txt" 2>/dev/null || true
    note "launchctl list 스냅샷: $LIVE_DIR/launchctl-list.txt"
  fi

  step 2/8 "프로젝트 plist 복사"
  local copied=0
  for p in "$HOME/Library/LaunchAgents"/*.plist; do
    [ -f "$p" ] || continue
    label="$(basename "$p")"
    case "$label" in
      com.pyw31337.*|com.lets*|com.moyeora.*|com.cultureflow.*|com.limery.*)
        cp "$p" "$PLIST_DIR/$label" && copied=$((copied + 1)) ;;
    esac
  done
  echo "  복사 ${copied}개 → bundle/launchagents"

  step 3/8 "crontab·런타임 버전"
  crontab -l > "$BUNDLE_DIR/crontab.bak" 2>/dev/null || : > "$BUNDLE_DIR/crontab.bak"
  {
    echo "# exported_at $(date '+%Y-%m-%dT%H:%M:%S%z')"
    echo "## host: $(hostname) / $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
    echo "## chip: $(sysctl -n machdep.cpu.brand_string 2>/dev/null) / mem: $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))GB"
    echo "## node: $(node -v 2>/dev/null || echo none)"
    echo "## python3: $(python3 -V 2>&1 || echo none)"
    echo "## git: $(git --version 2>/dev/null || echo none)"
    echo "## gh: $(gh --version 2>/dev/null | head -1 || echo none)"
    echo "## ollama: $(ollama --version 2>/dev/null || echo none)"
    echo "## ollama models:"; ollama list 2>/dev/null | awk 'NR>1 {print "   " $1}' || true
    echo "## brew formulae:"; brew list --formula 2>/dev/null | sort || true
    echo "## brew casks:"; brew list --cask 2>/dev/null | sort || true
    echo "## pmset:"; pmset -g custom 2>/dev/null || true
  } > "$LIVE_DIR/runtime-versions.txt"
  note "런타임·전원 설정: $LIVE_DIR/runtime-versions.txt"

  step 4/8 "SSH 별칭·GitHub 인증 (이름만)"
  {
    echo "# ~/.ssh/config 별칭 (키 내용은 담지 않음)"
    if [ -f "$HOME/.ssh/config" ]; then
      grep -iE '^\s*(Host|IdentityFile|HostName)' "$HOME/.ssh/config" 2>/dev/null | sed 's/^\s*//' || true
    else
      echo "(ssh config 없음)"
    fi
    echo ""
    echo "# gh auth (토큰 제외)"
    gh auth status 2>&1 | sed -E 's/(token:).*/\1 [숨김]/' || true
  } > "$LIVE_DIR/ssh-and-auth.txt"
  note "→ $LIVE_DIR/ssh-and-auth.txt"

  step 5/8 "로컬 런타임 실측"
  local rpt="$LIVE_DIR/local-dirs-report.tsv"
  printf 'path\tsize\tfiles\ttop_entries\n' > "$rpt"
  if [ -f "$DIRS_TSV" ]; then
    local rel sz full
    while IFS="$(printf '\t')" read -r rel sz; do
      [ -z "${rel:-}" ] && continue
      full="$HOME/$rel"
      if [ -d "$full" ]; then
        local bytes files
        bytes="$(du -sk "$full" 2>/dev/null | awk '{print $1}')"
        bytes="${bytes:-0}"
        files="$(find "$full" -type f 2>/dev/null | wc -l | tr -d ' ')"
        printf '%s\t%s\t%s\t%s\n' "$rel" "$((bytes / 1024))M" "$files" "$(ls "$full" 2>/dev/null | head -6 | tr '\n' ',' )" >> "$rpt"
      else
        printf '%s\tMISSING\t0\t-\n' "$rel" >> "$rpt"
      fi
    done < "$DIRS_TSV"
  fi
  echo "  → $rpt"

  step 6/8 "시크릿 이름만 추출 (값은 읽지 않음)"
  : > "$SECRET_KEYS_FILE"
  local f
  for f in \
    "$HOME/Developer/newsboard-local/local.env" \
    "$HOME/.letscamp/env" \
    "$HOME/.limery/env" \
    "$BASE_DIR/config/alert.env" \
    "$BASE_DIR/config/local.env" ; do
    [ -f "$f" ] || continue
    echo "# $f" >> "$SECRET_KEYS_FILE"
    sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=.*/\2/p' "$f" 2>/dev/null | sort -u | sed 's/^/  /' >> "$SECRET_KEYS_FILE"
    echo "" >> "$SECRET_KEYS_FILE"
  done
  if [ -s "$SECRET_KEYS_FILE" ]; then
    ok "키 이름 $(grep -c '^  ' "$SECRET_KEYS_FILE")개 기록"
  else
    note "읽을 수 있는 env 파일이 없습니다. 값은 별도로 옮기세요."
  fi

  step 7/8 "유출 점검 (토큰처럼 보이는 문자열)"
  local leak=0
  if grep -rInE '(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[A-Za-z0-9_-]{20,})' "$LIVE_DIR" "$BUNDLE_DIR/crontab.bak" 2>/dev/null > "$LIVE_DIR/leak-scan.txt"; then
    leak=1
  fi
  if [ "$leak" -eq 1 ]; then
    miss "번들에서 토큰 형태 문자열이 발견됐습니다. 아래 파일을 직접 확인하고 지우세요:"
    sed -n '1,10p' "$LIVE_DIR/leak-scan.txt"
    FAILED+=("유출 점검")
  else
    ok "번들에 토큰 형태 문자열 없음"
  fi

  step 8/8 "SSD로 복사"
  if [ -n "$SSD" ]; then
    if [ ! -d "$SSD" ]; then
      miss "SSD 경로가 없습니다: $SSD"
    elif [ "$DRY_RUN" -eq 1 ]; then
      note "[dry-run] rsync 로컬 런타임 + bundle → $SSD"
    else
      mkdir -p "$SSD/lets_bundle" "$SSD/lets_runtimes"
      rsync -a "$BUNDLE_DIR"/ "$SSD/lets_bundle"/ 2>/dev/null && ok "bundle → $SSD/lets_bundle"
      if [ -f "$DIRS_TSV" ]; then
        local rel sz
        while IFS="$(printf '\t')" read -r rel sz; do
          [ -z "${rel:-}" ] && continue
          if [ -d "$HOME/$rel" ]; then
            echo "  복사 $rel ($sz)…"
            mkdir -p "$SSD/lets_runtimes/$(dirname "$rel")"
            rsync -a --delete "$HOME/$rel/" "$SSD/lets_runtimes/$rel/" || { miss "$rel 복사 실패"; FAILED+=("$rel"); }
          fi
        done < "$DIRS_TSV"
      fi
      ok "런타임 → $SSD/lets_runtimes"
    fi
  else
    warn "--ssd 경로가 없어 복사는 건너뜁니다."
    note "예: --ssd /Volumes/IMAC_MIGRATION"
  fi

  {
    echo "# 인계 번들 내보내기 요약"
    echo "- 시각: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- 기기: $(hostname) / $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    echo "- 사용자 launchd 후보: ${count}개 / 프로젝트 plist: ${copied}개"
    echo "- crontab: $(wc -l < "$BUNDLE_DIR/crontab.bak" | tr -d ' ')줄"
    echo "- 런타임 보고서: $rpt"
    echo "- 시크릿 키 이름: $SECRET_KEYS_FILE (값 없음)"
    echo "- 복사 위치: ${SSD:-미지정}"
  } > "$LIVE_DIR/export-summary.md"

  summary "내보내기"
}

# ------------------------------------------------------------------------------
# import  (아이맥에서 실행)
# ------------------------------------------------------------------------------
cmd_import() {
  head_ "아이맥 M1 → 복원·등록"
  if ! is_mac; then
    miss "macOS에서만 실행할 수 있습니다. (현재 $(uname -s))"
    return 2
  fi
  local src_home; src_home="$(source_home)"
  note "원본 홈: $src_home → 이 기기 홈: $HOME"

  step 1/8 "사전 점검"
  local failed_pre=0
  [ "$(uname -m)" = "arm64" ] && ok "Apple Silicon" || { warn "arm64가 아닙니다: $(uname -m)"; failed_pre=1; }
  have brew && ok "Homebrew" || { miss "Homebrew 없음 → https://brew.sh"; failed_pre=1; }
  have git || { miss "git 없음 → xcode-select --install"; failed_pre=1; }
  local free_gb
  free_gb="$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')"; free_gb="${free_gb:-0}"
  if [ "$free_gb" -ge 70 ] 2>/dev/null; then ok "여유 공간 ${free_gb}GB"; else warn "여유 공간 ${free_gb}GB — 70GB 이상 권장"; fi
  if [ -f "$MANIFEST" ]; then ok "번들 매니페스트"; else miss "bundle/manifest.json 없음"; fi
  if [ "$failed_pre" -eq 1 ] && [ "$YES" -eq 0 ]; then
    warn "필수 도구가 부족합니다. 계속하려면 --yes 를 붙여 다시 실행하세요."
    return 1
  fi

  step 2/8 "저장소 클론"
  mkdir -p "$WORKSPACE"
  if [ -f "$REPOS_TSV" ]; then
    local name url branch dest
    while IFS="$(printf '\t')" read -r name url branch; do
      [ -z "${name:-}" ] && continue
      dest="$WORKSPACE/$name"
      if [ -d "$dest/.git" ]; then
        note "이미 있음: $name"
      elif [ "$DRY_RUN" -eq 1 ]; then
        note "[dry-run] clone $url → $dest"
      else
        if git clone --branch "${branch:-main}" "$url" "$dest" >/dev/null 2>&1; then
          ok "clone $name"
        else
          miss "clone 실패: $name"
          FAILED+=("clone:$name")
        fi
      fi
    done < "$REPOS_TSV"
  fi

  step 3/8 "런타임 복원 (SSD)"
  if [ -n "$SSD" ] && [ -d "$SSD/lets_runtimes" ] && [ -f "$DIRS_TSV" ]; then
    local rel sz
    while IFS="$(printf '\t')" read -r rel sz; do
      [ -z "${rel:-}" ] && continue
      if [ -d "$SSD/lets_runtimes/$rel" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
          note "[dry-run] $rel ($sz)"
        else
          mkdir -p "$(dirname "$HOME/$rel")"
          if rsync -a "$SSD/lets_runtimes/$rel/" "$HOME/$rel/"; then
            ok "$rel ($sz)"
          else
            miss "$rel 복사 실패"; FAILED+=("runtime:$rel")
          fi
        fi
      else
        note "SSD에 없음: $rel (설치 스크립트로 재생성)"
        SKIPPED+=("runtime:$rel")
      fi
    done < "$DIRS_TSV"
  else
    warn "SSD 런타임 경로가 없어 건너뜁니다: ${SSD:-미지정}"
  fi

  step 4/8 "launchd 재등록 (경로 치환)"
  mkdir -p "$HOME/Library/LaunchAgents"
  local uid_n p base target
  uid_n="$(id -u)"
  if [ -d "$PLIST_DIR" ]; then
    for p in "$PLIST_DIR"/*.plist; do
      [ -f "$p" ] || continue
      base="$(basename "$p")"
      target="$HOME/Library/LaunchAgents/$base"
      if [ "$src_home" != "$HOME" ]; then
        sed "s|$src_home|$HOME|g" "$p" > "$target"
      else
        cp "$p" "$target"
      fi
      if [ "$DRY_RUN" -eq 1 ]; then
        note "[dry-run] $base"
        continue
      fi
      launchctl bootout "gui/$uid_n" "$target" >/dev/null 2>&1 || true
      if launchctl bootstrap "gui/$uid_n" "$target" >/dev/null 2>&1; then
        ok "$base"
      else
        miss "$base 등록 실패(실행 파일 누락 가능)"
        FAILED+=("launchd:$base")
      fi
    done
  fi
  # plist가 가리키는 로그 폴더를 미리 만든다
  if have python3; then
    python3 - "$HOME/Library/LaunchAgents" "$src_home" "$HOME" <<'PY' 2>/dev/null || true
import glob, os, plistlib, sys
d, old, new = sys.argv[1:4]
for f in glob.glob(os.path.join(d, '*.plist')):
    try:
        p = plistlib.load(open(f, 'rb'))
    except Exception:
        continue
    for k in ('StandardOutPath', 'StandardErrorPath'):
        v = p.get(k)
        if v:
            os.makedirs(os.path.dirname(v.replace(old, new)), exist_ok=True)
PY
  fi

  step 5/8 "재설치가 필요한 로컬 작업"
  if [ "$DRY_RUN" -eq 1 ]; then
    note "[dry-run] camp install.sh · cctv 주소 갱신 · 라임리 가족 분석"
  else
    if [ -f "$WORKSPACE/camp/local/macmini/install.sh" ]; then
      if [ "$YES" -eq 1 ]; then
        bash "$WORKSPACE/camp/local/macmini/install.sh" >/dev/null 2>&1 && ok "camp nightshift 재설치" || { miss "camp nightshift 재설치 실패"; FAILED+=("camp"); }
      else
        note "camp nightshift: --yes 를 붙이면 자동 실행 (권장: 직접 실행해 로그 확인)"
      fi
    fi
    if [ -f "$WORKSPACE/cctv/ops/install-playback-address-refresh.sh" ]; then
      if [ "$YES" -eq 1 ]; then
        bash "$WORKSPACE/cctv/ops/install-playback-address-refresh.sh" >/dev/null 2>&1 && ok "CCTV 주소 갱신 재설치" || { miss "CCTV 재설치 실패"; FAILED+=("cctv"); }
      fi
    fi
    if [ -f "$WORKSPACE/limery/scripts/ops/install-daily-family-review.sh" ]; then
      if [ "$YES" -eq 1 ]; then
        bash "$WORKSPACE/limery/scripts/ops/install-daily-family-review.sh" --with-lets-calendar >/dev/null 2>&1 && ok "라임리 가족 분석 재설치" || { miss "라임리 재설치 실패"; FAILED+=("limery"); }
      fi
    fi
  fi
  note "모여라·컬처플로우·CCTV 설정은 calendar backup.sh → restore.sh 로 복원하세요(문서 4단계)."

  step 6/8 "Python 가상환경·Ollama"
  local nb="$HOME/Developer/newsboard-local"
  if [ -d "$nb" ] && [ "$DRY_RUN" -eq 0 ]; then
    if [ ! -x "$nb/venv/bin/python" ]; then
      python3 -m venv "$nb/venv" >/dev/null 2>&1 && ok "newsboard venv 생성" || { miss "venv 생성 실패"; FAILED+=("venv"); }
    else
      note "newsboard venv 이미 있음"
    fi
    if [ -f "$nb/requirements.txt" ] && [ -x "$nb/venv/bin/pip" ]; then
      "$nb/venv/bin/pip" install -q -r "$nb/requirements.txt" >/dev/null 2>&1 && ok "python 패키지 설치" || warn "requirements 설치 일부 실패"
    fi
  fi
  if have ollama; then
    launchctl setenv OLLAMA_MAX_LOADED_MODELS 1 2>/dev/null || true
    launchctl setenv OLLAMA_NUM_PARALLEL 1 2>/dev/null || true
    if [ "$YES" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] && [ -f "$BUNDLE_DIR/ollama_models.txt" ]; then
      local m
      while IFS= read -r m; do [ -n "$m" ] && ollama pull "$m" >/dev/null 2>&1 && ok "모델 $m"; done < "$BUNDLE_DIR/ollama_models.txt"
    fi
  else
    warn "Ollama 없음 — nightshift·문화 AI는 Apple Vision/CLIP만으로 축소 동작합니다."
  fi

  step 7/8 "전원·잠자기"
  if [ "$APPLY_PMSET" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    sudo pmset -a sleep 0 disksleep 0 autorestart 1 displaysleep 10 && ok "pmset 적용"
  else
    note "야간 작업이 멈추지 않게: sudo pmset -a sleep 0 disksleep 0 autorestart 1 displaysleep 10"
  fi

  step 8/8 "검증"
  cmd_verify || true
  summary "복원"
}

# ------------------------------------------------------------------------------
# verify
# ------------------------------------------------------------------------------
cmd_verify() {
  head_ "인계 검증"
  local fails=0
  local src_home; src_home="$(source_home)"

  echo "launchd"
  local p base label loaded target
  if [ -d "$PLIST_DIR" ]; then
    for p in "$PLIST_DIR"/*.plist; do
      [ -f "$p" ] || continue
      base="$(basename "$p")"; label="${base%.plist}"
      if have launchctl && launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
        ok "$label (등록됨)"
      else
        miss "$label (미등록)"; fails=$((fails + 1))
      fi
    done
  else
    warn "bundle/launchagents 없음"
  fi

  echo ""
  echo "실행 파일"
  local target_path
  if [ -d "$PLIST_DIR" ] && have python3; then
    while IFS="$(printf '\t')" read -r label target_path; do
      [ -z "${label:-}" ] && continue
      [ "$target_path" = "-" ] && continue
      target_path="${target_path//$src_home/$HOME}"
      if [ -e "$target_path" ]; then ok "$(basename "$target_path")"
      else miss "$label → $target_path"; fails=$((fails + 1)); fi
    done < <(python3 - "$PLIST_DIR" <<'PY'
import glob, os, plistlib, sys
for f in sorted(glob.glob(os.path.join(sys.argv[1], '*.plist'))):
    try: d = plistlib.load(open(f, 'rb'))
    except Exception: continue
    args = d.get('ProgramArguments') or [d.get('Program') or '']
    t = next((a for a in args if isinstance(a, str) and (a.endswith('.sh') or a.endswith('.py') or a.endswith('.mjs'))), '-')
    print(f"{d.get('Label','?')}\t{t}")
PY
)
  fi

  echo ""
  echo "심박 산출물 (macmini-health 기준 6h 경고 / 36h 실패)"
  if have gh; then
    local path updated age
    for path in "reporters_local.json" "overlay/latest.json"; do
      updated="$(gh api "repos/pyw31337/news/commits?sha=data&path=$path&per_page=1" --jq '.[0].commit.committer.date' 2>/dev/null || echo '')"
      if [ -z "$updated" ]; then
        warn "$path — 조회 실패(권한/네트워크)"
      else
        age="$(python3 - "$updated" <<'PY' 2>/dev/null || echo '?'
import datetime as dt, sys
t = dt.datetime.fromisoformat(sys.argv[1].replace('Z', '+00:00'))
print(round((dt.datetime.now(dt.timezone.utc) - t).total_seconds() / 3600, 1))
PY
)"
        if [ "$age" = "?" ]; then warn "$path — $updated"
        elif python3 -c "import sys; sys.exit(0 if float('$age') <= 6 else 1)" 2>/dev/null; then ok "$path — ${age}시간 전"
        elif python3 -c "import sys; sys.exit(0 if float('$age') <= 36 else 1)" 2>/dev/null; then warn "$path — ${age}시간 전 (경고)"
        else miss "$path — ${age}시간 전 (실패 임계 초과)"; fails=$((fails + 1)); fi
      fi
    done
  else
    warn "gh 없음 — 심박 확인 건너뜀"
  fi

  echo ""
  if [ "$fails" -eq 0 ]; then
    printf '\033[0;32m검증 통과\033[0m — 실패 0건\n'
    return 0
  else
    printf '\033[0;31m검증 실패 %s건\033[0m — 위 × 항목을 먼저 해결하세요\n' "$fails"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# secrets
# ------------------------------------------------------------------------------
cmd_secrets() {
  head_ "시크릿 체크리스트 (값은 다루지 않음)"
  echo "이 명령은 이름과 파일 위치만 보여줍니다. 값은 이 화면·로그·Git에 남기지 마세요."
  echo ""
  echo "1. GitHub — gh auth login 후:"
  echo "   gh auth status && gh auth setup-git"
  echo "   ssh -T git@github-newsboard      # 뉴스보드 push 별칭 확인"
  echo ""
  echo "2. 키체인 항목(직접 확인):"
  echo "   security find-generic-password -s 'gh:github.com' >/dev/null && echo 'gh 키체인 있음'"
  echo "   # + 모여라 사진 분석 토큰, 맥 백업 암호, SSH 키 passphrase"
  echo ""
  echo "3. env 파일 — 아래 파일을 열어 값만 채웁니다:"
  echo "   ~/Developer/newsboard-local/local.env"
  echo "   ~/.letscamp/env            (camp install.sh가 비우므로 기존 값 먼저 백업)"
  echo "   ~/.limery/env · limery/assets/config.local.js · ~/.wrangler/config/default.toml"
  echo "   ~/Developer/lets/config/alert.env"
  echo ""
  if [ -f "$SECRET_KEYS_FILE" ]; then
    echo "4. 맥미니에서 넘어온 키 이름 ($SECRET_KEYS_FILE):"
    sed 's/^/   /' "$SECRET_KEYS_FILE" | head -60
  else
    echo "4. 맥미니에서 넘어온 키 이름:"
    warn "secret-keys-only.txt 없음 — 맥미니에서 export를 먼저 실행하세요."
  fi
  echo ""
  echo "5. GitHub Actions 시크릿은 계정이 유지되면 그대로 동작합니다(재등록 불필요)."
  echo "   저장소별 이름은 pyw31337/macmini-workflow-handoff README 참고."
}

# ------------------------------------------------------------------------------
# retire
# ------------------------------------------------------------------------------
cmd_retire() {
  head_ "맥미니 작업 내리기"
  if ! is_mac; then
    miss "macOS에서만 실행할 수 있습니다. (현재 $(uname -s))"
    return 2
  fi
  echo "아이맥에서 심박 산출물 2개가 갱신된 것을 먼저 확인하세요:"
  echo "  bash scripts/migrate_to_imac_m1.sh verify"
  echo ""
  if [ "$YES" -eq 0 ]; then
    warn "실제로 내리려면 --yes 를 붙여 다시 실행하세요. (미리보기만 했습니다)"
    local p
    for p in "$HOME/Library/LaunchAgents"/*.plist; do
      [ -f "$p" ] || continue
      case "$(basename "$p")" in
        com.pyw31337.*|com.lets*|com.moyeora.*|com.cultureflow.*|com.limery.*) echo "  내릴 대상: $(basename "$p")" ;;
      esac
    done
    return 0
  fi

  local uid_n p label down=0
  uid_n="$(id -u)"
  for p in "$HOME/Library/LaunchAgents"/*.plist; do
    [ -f "$p" ] || continue
    label="$(basename "$p" .plist)"
    case "$label" in
      com.pyw31337.*|com.lets*|com.moyeora.*|com.cultureflow.*|com.limery.*)
        if launchctl bootout "gui/$uid_n" "$p" >/dev/null 2>&1; then
          ok "내림 $label"; down=$((down + 1))
        else
          note "이미 내려가 있음 $label"
        fi
        ;;
    esac
  done
  echo "  $down 개 작업을 내렸습니다. plist는 남겨 두었습니다(다시 켤 수 있음)."

  if [ "$FINAL" -eq 1 ]; then
    echo ""
    echo "마지막 정리(비밀값 흔적 제거)"
    local trash="$HOME/.migrated_trash"
    mkdir -p "$trash"
    local f moved=0
    for f in "$HOME/Developer/newsboard-local/local.env" "$HOME/.letscamp/env" "$HOME/.limery/env"; do
      if [ -f "$f" ]; then
        mv "$f" "$trash/$(echo "$f" | tr '/' '_')" && ok "이동 $f → $trash"; moved=$((moved + 1))
      fi
    done
    echo "  이동 $moved 개 (삭제하지 않고 $trash 에 보관)"
    echo ""
    echo "직접 실행하세요(이 스크립트가 대신 하지 않음):"
    echo "  gh auth logout"
    echo "  security delete-generic-password -s 'gh:github.com'   # 필요 시"
    echo "  rm -rf ~/.ssh/id_ed25519_newsboard*                    # 별칭 키 확인 후"
    echo "  # 키체인의 모여라 토큰·백업 암호도 삭제"
    echo "  # 회사 계정 로그아웃 후 기기 반납"
  fi
}

summary() {
  echo ""
  printf '\033[0;34m----------------------------------------------------------------\033[0m\n'
  printf '  %s 결과\n' "$1"
  if [ ${#FAILED[@]} -eq 0 ]; then printf '  실패 0건\n'; else printf '  \033[0;31m실패 %s건\033[0m: %s\n' "${#FAILED[@]}" "${FAILED[*]}"; fi
  if [ ${#SKIPPED[@]} -gt 0 ]; then printf '  건너뜀: %s\n' "${SKIPPED[*]}"; fi
  printf '\033[0;34m----------------------------------------------------------------\033[0m\n'
}

case "$CMD" in
  plan) cmd_plan ;;
  export) cmd_export ;;
  import) cmd_import ;;
  verify) cmd_verify ;;
  secrets) cmd_secrets ;;
  retire) cmd_retire ;;
  help|*) cat <<'USAGE'
Let’s 인계 엔진 — 맥미니 → 아이맥 M1

  plan                     현재 기기 확인 + 순서 안내 (기본)
  export [--ssd 경로]      맥미니에서: launchd 전체 재스캔·목록·시크릿 이름·SSD 복사
  import [--ssd 경로]      아이맥에서: 저장소·런타임·launchd 복원  (--yes 로 설치 실행)
  verify                   등록·실행 파일·심박 산출물 검증 (읽기 전용)
  secrets                  시크릿 이름·위치 체크리스트 (값 없음)
  retire [--yes] [--final] 맥미니에서: 작업 내리기 · 마지막 정리

  공통: --dry-run  --workspace 경로  --apply-pmset
USAGE
  ;;
esac
