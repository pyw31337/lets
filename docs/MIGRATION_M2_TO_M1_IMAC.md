# 회사 Mac mini (M2) → 집 iMac (M1) 이관 가이드 (2026년 12월 말)

회사 M2 Mac mini 사용 종료에 맞춰, 집 M1 iMac으로 LetsHub 및 16대 서비스 로컬 워크플로우를 무중단으로 이전하기 위한 체크리스트입니다.

---

## 1. M2 Mac mini → M1 iMac 전환 시 핵심 차이점
1. **메모리·동시 추론 제한 (M1 8~16GB 통합 메모리 보호)**
   - M1 iMac은 M2 대비 메모리 대역폭이 낮으므로 Ollama가 여러 모델(`qwen2.5vl:3b`, `llama3.2:1b` 등)을 동시에 메모리에 올리지 않도록 제한해야 합니다.
   - `restore_on_new_pc.sh`가 자동으로 `OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_NUM_PARALLEL=1`, `OLLAMA_KEEP_ALIVE=5m`을 설정합니다.
2. **iMac 잠자기(Sleep) 방지 (`pmset`)**
   - Mac mini와 달리 iMac은 기본 절전 모드가 켜져 있어 새벽/야간 LaunchAgent 배치가 멈출 수 있습니다.
   - 복원 시 `--apply-pmset` 옵션을 주거나 아래 명령을 실행해 화면만 끄고 시스템은 깨어 있도록 설정하세요.
     ```bash
     sudo pmset -a sleep 0 disksleep 0 autorestart 1 displaysleep 10
     ```
3. **사용자 홈 경로(`/Users/<계정>`) 자동 치환**
   - 회사 맥미니와 집 아이맥의 macOS 사용자명이 다를 경우 `.plist` 내부 경로가 깨집니다.
   - `restore_on_new_pc.sh`는 `manifest.json`의 `source_machine.home`을 읽어 집 iMac의 `$HOME`으로 자동 치환하고 로그 디렉토리까지 생성한 뒤 `launchctl bootstrap`을 수행합니다.

---

## 2. 이관 절차

### Step A. 회사 M2 Mac mini에서 백업 번들 생성 & 대용량 런타임 내보내기
```bash
cd ~/Developer/lets
./scripts/ecosystem_handoff_bundle.sh
# 대용량 비-Git 런타임(newsboard-local 55GB, .letscamp 5.6GB 등)을 외장 SSD로 복사:
./scripts/sync_local_runtimes.sh export /Volumes/MySSD/lets_runtimes
```
생성물: `bundle/lets_ecosystem_handoff_pack.tar.gz`
- **13개 전체 `LaunchAgents/*.plist`** (`com.cultureflow.*`, `com.letscamp.*`, `com.limery.*`, `com.moyeora.*`, `com.pyw31337.*`)
- `crontab.bak`, `ollama_models.txt` (4종), `repos.tsv` (Git 저장소 목록), `local_dirs.tsv` (비-Git 런타임 목록)
- `env_backup/` (`.env`, `config/alert.env`, `~/.letscamp/env`, `media-worker.json` — **Git 커밋 제외, AirDrop/외장 SSD로만 이동**)

### Step B. 집 M1 iMac에서 원클릭 복원
1. Homebrew, GitHub CLI 로그인 확인:
   ```bash
   gh auth login
   ```
2. `lets` 저장소 클론 후 아카이브 풀기 & 원클릭 복원:
   ```bash
   mkdir -p ~/Developer && cd ~/Developer
   git clone https://github.com/pyw31337/lets.git
   cd lets
   tar -xzf lets_ecosystem_handoff_pack.tar.gz
   ./scripts/restore_on_new_pc.sh --dry-run
   # 외장 SSD의 런타임까지 한 번에 복원 + iMac 절전 방지 적용:
   ./scripts/restore_on_new_pc.sh --apply-pmset --runtime-source /Volumes/MySSD/lets_runtimes
   ```
   > Finder에서 `bundle/one_click_restore.command` 를 **더블클릭**해도 동일하게 원클릭 복원이 실행됩니다.
3. 복원 확인:
   ```bash
   ollama list
   launchctl list | grep -E "pyw31337|letscamp|moyeora"
   python3 scripts/collect_live_status.py && python3 scripts/aggregate_collection_pulse.py && python3 scripts/audit_truth_contract.py
   ```

---

## 3. 회사 M2 Mac mini 반납 전 정리 (중복 실행 방지)
집 M1 iMac에서 1~2일 정상 가동을 확인한 뒤, 회사 Mac mini에서 백그라운드 작업을 중지하고 토큰을 정리하세요.
```bash
UID_NUM=$(id -u)
for plist in ~/Library/LaunchAgents/com.pyw31337.*.plist ~/Library/LaunchAgents/com.letscamp.*.plist ~/Library/LaunchAgents/com.moyeora.*.plist; do
  [ -f "$plist" ] && launchctl bootout "gui/$UID_NUM" "$plist" 2>/dev/null || true
done
gh auth logout
```
- GitHub Secrets(`LETS_STATUS_TOKEN`, `TELEGRAM_BOT_TOKEN` 등)는 GitHub Actions에서 계속 동작하므로 변경할 필요가 없으며, 회사 PC 로컬 `.env`와 SSH 키만 삭제하면 됩니다.
