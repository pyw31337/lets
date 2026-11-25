# 아이맥 M1 인계 런북 (회사 Mac mini → 집 iMac)

> 회사 재직 마지막 달(2026-12) 안에 맥미니의 로컬 자동화를 집 아이맥 M1으로 옮기기 위한 실행 문서입니다.
> 화면용 요약은 [`handoff.html`](../handoff.html), 스크립트는 [`scripts/migrate_to_imac_m1.sh`](../scripts/migrate_to_imac_m1.sh)에 있습니다.
> **시크릿 값은 이 문서·저장소·화면 어디에도 적지 않습니다. 이름과 위치만 다룹니다.**

---

## 0. 한눈에

| 구분 | 값 | 근거 |
|---|---|---|
| 원본 기기 | Mac mini · Apple M2 · 8GB · `/Users/pyw31337` | `bundle/manifest.json` (2026-11-25 01:48Z 내보내기) |
| 대상 기기 | iMac · Apple M1 · 16GB · 512GB *(기기에서 확인 필요)* | 라임리 `docs/MIGRATION_NEW_MACHINE.md` |
| 이전할 로컬 작업 | **13개 launchd** | `bundle/launchagents/` |
| crontab | **0건** (빈 파일) | `bundle/crontab.bak` |
| 옮길 비-Git 런타임 | **7개 · 약 61.4GB** | `bundle/local_dirs.tsv` |
| 다시 받을 저장소 | **17개** | `bundle/repos.tsv` |
| Ollama 모델 | 4종 (qwen2.5:3b, llama3.2:3b, llama3.2:1b, qwen2.5vl:3b) | `bundle/ollama_models.txt` |
| GitHub Actions | 23개 저장소 · 워크플로 158개 · cron 100건 → **이전 불필요** | 2026-11-26 GitHub API 집계 |
| 심박 점검 | `news` 저장소 `macmini-health` (매시 :25, 6h 경고 / 36h 실패) | `.github/workflows/macmini-watch.yml` |

**결론**: 클라우드(Actions·Cloudflare·Supabase·R2)는 그대로 두면 됩니다. 실제로 옮겨야 하는 것은 **로컬에서만 도는 13개 작업과 그 런타임 61.4GB, 그리고 그 작업들이 쓰는 비밀값**입니다.

---

## 1. 이전 대상 — 로컬 launchd 13개

| # | label | 하는 일 | 스케줄 | 의존 런타임 | 이전 방식 |
|---|---|---|---|---|---|
| 1 | `com.pyw31337.newsboard-ai` | 뉴스 수집·해외 번역·보강 → data 브랜치 push | 30분마다 | newsboard-local 55G · SSH 별칭 · venv | 수동(SSD) |
| 2 | `com.pyw31337.newsboard-analyze` | 분석 → `overlay/latest.json` (심박) | 매시 45분 | newsboard-local · venv | 수동(SSD) |
| 3 | `com.pyw31337.newsboard-dispatch` | 발송 큐 처리 | 매시 12·42분 | newsboard-local | 수동(SSD) |
| 4 | `com.pyw31337.newsboard-gov` | 공공 자료 수집 | 매시 20분 · 로그인 시 | newsboard-local · 공공 API 키 | 수동(SSD) |
| 5 | `com.pyw31337.newsboard-journalists` | 기자 아카이브 → `reporters_local.json` (심박) | 매시 20분 · 로그인 시 | newsboard-local · venv | 수동(SSD) |
| 6 | `com.pyw31337.newsboard-pol` | 국회·공보 수집 | 매일 02:50 | newsboard-local | 수동(SSD) |
| 7 | `com.letscamp.nightshift` | 사진·글 판독(허용 시간대만) | 15분마다 | `.letscamp` 5.6G · Vision 바이너리 · Ollama | `camp/local/macmini/install.sh` |
| 8 | `com.moyeora.media-analysis` | 사진 분석·얼굴 인물 추천 | 15분마다 · 로그인 시 | calendar · App Support/Moyeora · 키체인 토큰 | calendar 백업→복원 |
| 9 | `com.moyeora.culture-intelligence` | 공연 동기화·품질·로컬 AI 검토 | 매일 02:20 | calendar · Ollama llama3.2:1b | calendar 백업→복원 |
| 10 | `com.cultureflow.local-scheduler` | 문화 데이터 수집 스케줄러 | 01:17·05:17·21:47 / 평일 18:37 / 주말 3회 | CultureFlow · API 키 8종 | calendar 백업→복원 |
| 11 | `com.cultureflow.update-watch` | 로컬 갱신 감시 | 매일 07:30 | CultureFlow | calendar 백업→복원 |
| 12 | `com.pyw31337.letsview.playback-addresses` | CCTV 재생 주소 갱신 | 30분마다 · 로그인 시 | `.cctv-ops` 418M | `cctv/ops/install-playback-address-refresh.sh` |
| 13 | `com.limery.daily-family-review` | 가족 관계 후보 매일 분석 | 매일 09:35 | limery · App Support/Limery · 렛츠캘린더 | `limery/scripts/ops/install-daily-family-review.sh` |

### 이전하지 않는 것
- **GitHub Actions 158개 워크플로**: GitHub 클라우드 러너에서 실행되므로 맥미니·아이맥과 무관합니다. 계정(`pyw31337`)과 저장소만 유지되면 계속 돕니다.
- **Cloudflare Pages·Workers·R2·D1, Supabase, Firebase**: 클라우드 자원입니다.
- **limery 저장소의 launchd 템플릿 22개**: 저장소에는 있으나 맥미니에는 1개만 등록되어 있었습니다. 아이맥에서 필요할 때 `bash scripts/install-launchd.sh --user <계정>`로 설치합니다(선택).

> ⚠ 11-25 번들은 `com.pyw31337.*`, `com.lets*`, `com.moyeora.*`, `com.cultureflow.*`, `com.limery.*` 다섯 접두사만 담았습니다. 다른 이름의 사용자 작업이 있으면 빠집니다. `migrate export`가 `~/Library/LaunchAgents` 전체와 `launchctl list`를 다시 훑어 메웁니다.

---

## 2. 옮길 로컬 런타임 — 7개 · 약 61.4GB

| 경로 | 크기 | 쓰는 작업 | 처리 |
|---|---|---|---|
| `~/Developer/newsboard-local` | 55G | 뉴스보드 6개 | **SSD 필수** (venv·local.env·upload-queue·data 체크아웃이 여기에만 있음) |
| `~/.letscamp` | 5.6G | 캠핑 nightshift | SSD 권장 (진행 상태·avoid.txt·holidays.txt·env) |
| `~/Library/Application Support/Moyeora` | 86M | 모여라 사진·문화 | **SSD 필수** (얼굴 데이터는 재생성 불가) |
| `~/.cctv-ops` | 418M | CCTV 주소 갱신 | 재설치 스크립트로 재생성 가능 |
| `~/Library/Application Support/Limery` | 273M | 라임리 가족 분석 | SSD 권장 (reports 이력) |
| `~/Developer/news` | 1.3M | 수동 작업 | git clone |
| `~/Developer/family_os_web` | 1.9M | 라임리(레거시 경로) | git clone → `~/Developer/limery` |

---

## 3. 저장소 17개

`CultureFlow`(← `cultureflow-ai-test`), `art`, `asset`, `buy`, `calendar`, `camp`, `cctv`, `cultureflow-ai-test`, `hair`, `insu`, `law`, `lets`, `limery`, `meat`, `metro`, `people`, `pick`.
전체 주소·브랜치는 `bundle/repos.tsv`에 있고, `migrate import`가 없는 것만 골라 클론합니다.

---

## 4. 시크릿·토큰 — 이름만, 값은 직접 입력

| 그룹 | 위치 | 이름 |
|---|---|---|
| GitHub | 키체인 · `~/.ssh` | `gh` 인증(gh:github.com), `~/.ssh/config`의 **Host github-newsboard** + IdentityFile, `id_ed25519_limery` 등, osxkeychain 자격증명 |
| 뉴스보드 | `~/Developer/newsboard-local/local.env` | `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`, `DATA_GO_KR_KEY`, `KAKAO_REST_KEY`, `DART_API_KEY`, `ECOS_API_KEY`, `ASSEMBLY_KEY`, `LAW_OC`, `ARCHIVE_KEY`, `LLM_API_KEY`, `LLM_ENDPOINT`, `LLM_MODEL`, `MEDIA_R2_SEC`, `NB_REMOTE` |
| 캠핑 | `~/.letscamp/env` | `LOCAL_VLM_MODEL`, (필요 시) `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| 라임리 | `~/.limery/env` · `assets/config.local.js` · `~/.wrangler/config/default.toml` | `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`, `FAMILY_ID`, `LIMERY_SYNC_STATUS_TOKEN`, R2 키 3종, Cloudflare API 토큰, **GPG passphrase**(구글 Keep) |
| 모여라 | 키체인 · App Support | 사진 분석 토큰, 맥 백업 암호, 저장소별 `.env` |
| 렛츠허브 | `config/alert.env` | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `DISCORD_WEBHOOK_URL`, `SLACK_WEBHOOK_URL`, (Actions) `LETS_STATUS_TOKEN` |

- `migrate export`는 env 파일에서 **키 이름만** 뽑아 `bundle/live/secret-keys-only.txt`에 남기고, 토큰 형태 문자열이 섞였는지 검사합니다.
- GitHub Actions 시크릿(camp 18 · news 13 · cctv 10 · metro 6 · culture 8 등)은 GitHub에 있으므로 **재등록 불필요**합니다. 저장소를 새로 만들 때만 `macmini-workflow-handoff` README의 이름 목록을 보세요.

---

## 5. 순서

### ① 12월 중순까지 · 맥미니
```bash
cd ~/Developer/lets && git pull
bash scripts/migrate_to_imac_m1.sh export --ssd /Volumes/IMAC_MIGRATION
zsh ~/Developer/calendar/tools/mac-automation/backup.sh --with-secrets
```
- `export`는 launchd 전체 재스캔, crontab, 버전·brew 목록, SSH 별칭(이름만), 로컬 런타임 실측, 시크릿 키 이름, 유출 점검, SSD 복사를 수행합니다.
- `backup.sh --with-secrets`는 모여라·컬처플로우·CCTV 설정을 **키체인 비밀값까지 AES-256으로** iCloud Drive `Moyeora Backups`에 담습니다(암호는 키체인, `--print-passphrase`로 확인).

### ② 퇴사 1주 전 · 아이맥
```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install node python gh ollama && gh auth login
git clone https://github.com/pyw31337/lets.git ~/Developer/lets
bash ~/Developer/lets/scripts/migrate_to_imac_m1.sh import --ssd /Volumes/IMAC_MIGRATION --apply-pmset --yes
```
`import`는 사전 점검 → 저장소 클론 → 런타임 복원 → plist 경로 치환·등록 → camp/CCTV/라임리 재설치 → venv·Ollama → pmset → 검증 순으로 진행하고, 실패 항목만 모아 보고합니다.

### ③ 가져온 직후 · 비밀값 채우기
```bash
bash ~/Developer/lets/scripts/migrate_to_imac_m1.sh secrets
# local.env · .letscamp/env · ~/.limery/env 값 입력
gh auth login && gh auth setup-git && ssh -T git@github-newsboard
zsh ~/Developer/calendar/tools/mac-automation/restore.sh "<iCloud의 최신 백업>.tar.gz"
```

### ④ 첫 성공 확인 후 · 맥미니 내리기 (같은 날)
```bash
# 아이맥
bash scripts/migrate_to_imac_m1.sh verify
# 맥미니
bash scripts/migrate_to_imac_m1.sh retire --yes
```
두 기기가 동시에 돌면 news **data 브랜치 push가 rebase 충돌**하고 camp nightshift가 같은 파일을 커밋합니다. 아이맥에서 심박 2개가 한 번 갱신된 것을 본 당일 내리세요.

### ⑤ 마지막 근무일 · 반납
```bash
bash scripts/migrate_to_imac_m1.sh retire --final   # env 파일을 ~/.migrated_trash/로 이동
gh auth logout
# 키체인(gh, 모여라 토큰, 백업 암호) · SSH 키 삭제 · 회사 계정 로그아웃 · SSD 사본 암호화 확인
```

---

## 6. 검증 — macmini-health

`news` 저장소의 `macmini-health` 워크플로가 **매시 25분**에 data 브랜치의 산출물 두 개를 봅니다.

| 산출물 | 만드는 작업 | 임계 |
|---|---|---|
| `reporters_local.json` | `com.pyw31337.newsboard-journalists` | 6h 경고 · 36h 실패 |
| `overlay/latest.json` | `com.pyw31337.newsboard-analyze` | 6h 경고 · 36h 실패 |

- 맥미니에 직접 접속하지 않고 **마지막 push 시각**을 심박으로 봅니다. 호스트 이름이 바뀌어도 경로가 같으면 그대로 동작합니다.
- 2026-11-26 05:20 KST 기준 두 파일 모두 갱신됨(정상).
- 이전 후에는 `bash scripts/migrate_to_imac_m1.sh verify`가 같은 기준(6h/36h)으로 두 파일의 나이를 계산해 보여줍니다.
- 아이맥에서 `launchctl kickstart -k gui/$(id -u)/com.pyw31337.newsboard-journalists`로 한 번 수동 실행해 첫 심박을 만들 수 있습니다.

---

## 7. 위험과 대비

1. **번들 스캔 범위** — 접두사 5종만 담겼을 수 있음 → `export`가 전체 재스캔.
2. **Swift 바이너리 3종** — `~/.letscamp/bin/vision-ocr`, `newsboard-local/bin/nbai`, calendar Vision 헬퍼. 복사하면 안 되고 각 설치 스크립트로 재컴파일. `nbai`는 Apple Intelligence(FoundationModels) 기반이라 아이맥 macOS가 낮으면 동작하지 않음 → `LLM_BACKEND=ollama`로 대체.
3. **Python venv** — 경로가 박혀 있어 복사하면 깨짐 → `import`가 새로 만듭니다.
4. **중복 실행** — 위 ④.
5. **메모리** — 16GB라도 Ollama 4종 동시 로드는 스왑을 만듭니다. `OLLAMA_MAX_LOADED_MODELS=1` 유지.
6. **회사 기기 초기화** — 마지막 날 MDM이 지우면 이후엔 꺼낼 수 없습니다. ①을 12월 중순까지.

---

## 8. 근거와 갱신

- launchd·런타임·저장소: 2026-11-25 01:48Z 맥미니에서 실제 실행한 번들 내보내기 결과.
- Actions 수치: 2026-11-26 `gh api .../actions/workflows` + 각 워크플로의 `cron:` 구문 집계.
- 심박: 2026-11-26 05:20 KST data 브랜치 커밋 확인.
- 번들을 새로 만들면 `bash scripts/build_handoff_package.sh`로 `packages/lets-imac-m1-handoff.tar.gz`를 다시 만들고 커밋하세요.
