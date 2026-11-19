# 렛츠 패밀리 통합 디자인 시스템 (Let's Design System, LDS v2.2.0)
> **최종 개정일**: 2026-11-19  
> **기준 레퍼런스**: Taste Skill 분석 결과 ("Tactile Modernism & Digital Craft"), Apple HIG 스퀘어클 규격, Dieter Rams 물리적 에르고노믹스, Linear/Raycast 마이크로 인터랙션  
> **적용 대상**: `Let's Hub`, `Let's Law`, `Let's Insu`, `Let's People`, `Let's Asset`, `Let's Art`, `Let's View`, `MeatTracker`, `Let's Camp` 등 생태계 전 서비스

---

## 1. Taste Archetype: Tactile Modernism & Digital Craft

### 1.1 스퀘어클 벤토 박스 (Squircle Bento Architecture)
- **수학적 곡률 일치 (`R_outer = R_inner + padding`)**:
  - 컨테이너와 내부 요소의 라운딩이 비례하여 조화를 이루는 스퀘어클 곡률 체계를 적용합니다.
  - 최상위 카드 곡률: `20px~26px`, 내부 세그먼트/버튼 곡률: `8px~14px`.
- **1px 초미세 헤어라인 보더 (`rgba(0, 0, 0, 0.05)`)**:
  - 탁한 1px solid 테두리가 아닌, 순백색 서피스 가장자리에 자연스러운 빛의 굴절감을 주는 초미세 투명 헤어라인을 적용합니다.
- **비클리핑 앰비언트 섀도우**:
  - `box-shadow: 0 4px 20px rgba(0, 0, 0, 0.04), 0 1px 3px rgba(0, 0, 0, 0.02)`

### 1.2 고정폭 타뷸러 숫자 (Tabular Figures Standard)
- 대시보드의 실시간 수집량, 처리율, 타임스탬프, 인퍼런스 건수 등 모든 메트릭 수치에는 반드시 **`font-variant-numeric: tabular-nums;`** 속성을 강제합니다.
- 숫자가 카운트업되거나 변할 때 텍스트 폭이 좌우로 흔들리는(jittering) 현상을 원천 방지하여 시각적 안정감을 보장합니다.

### 1.3 스프링 피직스 트랜지션 (Spring Physics)
- 기계적인 선형(Linear) 페이드를 금지하고, 실제 물리적 탄성을 모사한 **감쇠 스프링 커브(`cubic-bezier(0.16, 1, 0.3, 1)`)**를 기본 모션으로 사용합니다.

---

## 2. 로컬 에지 AI & Ollama 무인 관제 표준 (Local Edge AI Sentinel)

- 클라우드 API뿐만 아니라, 로컬 머신에서 독립적으로 가동되는 온디바이스 AI 파이프라인을 동일한 규격으로 관제합니다:
  - **Ollama 모델 2종 규격**:
    1. `qwen2.5vl:3b` (3.2 GB): 캠핑장 주변 사진 비전 판독 및 Apple Vision OCR 연동
    2. `llama3.2:1b` (1.3 GB): 매일 02:20 문화 지능 브리핑 로컬 요약 모델
  - **9대 로컬 LaunchAgents 데몬 사활 감시**:
    - `sh.brew.ollama`, `com.letscamp.nightshift`, `com.moyeora.culture-intelligence`, `com.pyw31337.letsview.*`, `com.pyw31337.newsboard.*`

---

## 3. PC 이관 및 무중단 인계 (Ecosystem Handoff System)

- 회사 PC, 홈 PC, 신규 Mac mini 등 작업 머신이 변경되어도 파이프라인이 1초도 중단되지 않도록 **원클릭 인계 패키지(`scripts/ecosystem_handoff_bundle.sh` & `restore_on_new_pc.sh`)**를 표준화합니다.
- LaunchAgents plist, Ollama 모델 다운로드 스크립트, 파이썬 가상환경 의존성을 단일 번들로 패키징하여 새 환경에서 자동 복구할 수 있도록 지원합니다.
