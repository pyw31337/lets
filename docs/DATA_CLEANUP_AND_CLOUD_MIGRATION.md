# 로컬 디스크·외장하드 전수 분류 및 클라우드 이관 가이드

> 기준 시점: 2026-11-25 (회사 M2 Mac mini 로컬 디스크 가용 공간 16GiB / 외장하드 `My Passport for Mac` 745GiB 사용 중)

---

## 1. 로컬 맥미니 폴더별 용도 및 필요 여부 구분

### A. 반드시 이관해야 하는 핵심 데이터 (GitHub에 없는 로컬 런타임·설정)
| 경로 | 용량 | 실제 담당 서비스 / 데몬 | 이관 방법 |
|---|---:|---|---|
| `~/Developer/lets/bundle/lets_ecosystem_handoff_pack.tar.gz` | **12KB** | 13개 LaunchAgents, `repos.tsv`, `ollama_models.txt`, `.env` 3종, 원클릭 복원 스크립트 | **Google Drive / AirDrop** |
| `~/Developer/newsboard-local/` | **55GB** (`.git` 33GB 제외 시 **~22GB**) | `newsboard-ai`, `analyze`, `dispatch`, `gov`, `journalists`, `pol` 6개 데몬 | `.git` 제외 후 `data`, `gov`, `mirror-data`, `ledger`, `pol` 압축 이관 |
| `~/.letscamp/` | **5.6GB** (`.git` 3.8GB 제외 시 **~1.8GB**) | `com.letscamp.nightshift` 데몬 (`camp` 야간 비전 OCR) | `env` + `db` + `data` + `pipeline` 위주 이관 (`.git` 제외) |
| `~/.cctv-ops/` | **417MB** | `com.pyw31337.letsview.playback-addresses` 데몬 | 전체 압축 이관 |
| `~/Library/Application Support/Limery/` | **273MB** | `com.limery.daily-family-review` 데몬 | 전체 압축 이관 |
| `~/Library/Application Support/Moyeora/` | **86MB** | `com.moyeora.media-analysis` 데몬 | 전체 압축 이관 |
| `~/Developer/camp` 내 미커밋 작업 (474건) | - | 로컬 작업 중 파일 | **이관 전 `git status` 확인 후 커밋/푸시 권장** |
| `~/Developer/limery` 내 미커밋 작업 (4건) | - | 로컬 작업 중 파일 | **이관 전 커밋/푸시 권장** |

### B. GitHub 원격으로 자동 복원되는 폴더 (클라우드/외장하드 백업 불필요)
아래 폴더들은 모두 GitHub (`pyw31337/*`)에 올라가 있으므로, 새 M1 iMac에서 `restore_on_new_pc.sh`가 `git clone`으로 새로 받습니다.
- `CultureFlow` (9.3GB — `.git` 5.1GB + `out`/`node_modules`/`.next` 빌드 캐시 2.8GB)
- `camp` (7.3GB — `.git` 6.3GB)
- `cctv` (3.6GB — `.git` 3.5GB)
- `metro` (1.2GB — `node_modules` 566MB + `out` 201MB)
- `calendar` (1.1GB — `node_modules` 244MB)
- `limery` (254MB), `hair` (156MB), `art` (137MB), `meat` (111MB), `pick` (14MB), `lets` (10MB), `people` (8.9MB), `asset` (1.0MB), `law` (864KB), `insu` (604KB)
- `~/.ollama` (**7.9GB**): 새 M1 iMac에서 `ollama pull`로 재설치 (백업 불필요)

### C. 로컬에서 미사용 / 중복 / 즉시 삭제 가능 후보
| 경로 | 용량 | 사유 |
|---|---:|---|
| `~/Developer/cultureflow-ai-test` | **3.3GB** | `CultureFlow` 테스트용 클론 (LaunchAgent 미사용, `git status` 클린) |
| `~/Developer/buy` | **11MB** | `service_lifecycle.json`상 `retired` (`cart`로 승격) |
| `~/Developer/subway` | **0B** | 빈 디렉토리 (`metro`로 대체) |
| `~/Developer/CultureFlow/{out,.next,node_modules}` | **2.4GB** | 로컬 빌드/패키지 캐시 (재생성 가능) |
| `~/Developer/metro/{node_modules,out}` | **767MB** | 로컬 빌드/패키지 캐시 (재생성 가능) |
| `~/Developer/news` (1.3MB), `~/Developer/family_os_web` (1.9MB) | **3.2MB** | `.git` 없는 구형 스냅샷 폴더 — 내용 확인 후 불필요 시 삭제 |

---

## 2. 회사 외장하드(`/Volumes/My Passport for Mac`, 745GB 사용) 분류

| 폴더 | 용량 | 성격 | 처리 방안 |
|---|---:|---|---|
| `박영우/` | **731GB** | 회사 디자인/인쇄물/전시부스 업무 산출물 (크레소티, 팜페이, 셀포스 등) | **회사 자산** — 외장하드에 유지하거나 회사 규정에 따라 정리 (개인 개발 이관 대상 아님) |
| `AS동영상(자막완료)/` | **1.3GB** | 회사 AS 동영상 자료 | **회사 자산** |
| `Codex-verified-archives/2026-11-18/` | **10GB** | 11/18 기준 `Developer`(4.5GB), `Developer-retry`(2.4GB), `Documents`(3.2GB) 백업 | `Developer*`는 GitHub 중복이므로 **즉시 삭제 가능**, `Documents`(3.2GB)만 개인 문서 여부 확인 후 Google Drive로 이동 뒤 삭제 |

> 현재 가동 중인 LaunchAgents 13개 중 외장하드(`/Volumes/My Passport for Mac`)를 참조하는 데몬은 **0건**입니다.

---

## 3. 회사 외장하드 없이 Google Drive / 클라우드로 이관하는 최적 방안

1. **Google Drive (개인 계정 15GB 무료 / Google One 100GB 월 2,400원)**
   - **1순위 업로드 (약 15KB)**: `lets_ecosystem_handoff_pack.tar.gz` (LaunchAgents 13개 + `.env` + 모델/레포 목록)
   - **2순위 업로드 (`--exclude='.git'` 기준 ~20~24GB, `tar.gz` 압축 시 더 감소)**:
     - `newsboard-local` (`news/.git` 33GB 제외)
     - `~/.letscamp` (`camp/.git` 3.8GB 제외)
     - `~/.cctv-ops`, `Application Support/Limery`, `Application Support/Moyeora`
     - (선택) 외장하드 `Codex-verified-archives/2026-11-18/Documents` (3.2GB)
   - 무료 15GB 한도를 넘기면 **Google One 100GB를 이관 기간 1~2개월만 구독**하거나, `newsboard-local/news/data`(8GB)와 `gov`/`mirror-data`/`ledger`/`pol`을 분할 압축해 올리는 것이 가장 간편합니다.
2. **집-회사 Mac 간 직접 전송 (비용 0원, 용량 제한 없음)**
   - **Tailscale + `rsync`**: 회사 Mac mini와 집 M1 iMac에 Tailscale을 깔면 외장하드나 클라우드 용량 제한 없이 `rsync -ahP --exclude='.git'`로 직접 고속 동기화할 수 있습니다.
