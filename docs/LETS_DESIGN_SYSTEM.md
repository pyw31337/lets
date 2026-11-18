# 렛츠 패밀리 통합 디자인 시스템 (Let's Design System, LDS v2.0.0)
> **최종 개정일**: 2026-11-18  
> **기준 레퍼런스**: 토스(Toss Simplicity) 미니멀 서피스, 렛츠캘린더 (`/calendar`), 뉴스보드 인물 상세 페이지 (`/news/person/`), Apple HIG  
> **적용 대상**: `Let's Law`, `Let's Insu`, `Let's People`, `Let's Asset`, `Let's Art`, `Let's View`, `MeatTracker`, `Let's Hub` 등 생태계 전 서비스

---

## 1. 토스(Toss) 스타일 미니멀 서피스 원칙 (Surface & Divider Standards)

### 1.1 선과 면의 최소화 (No Border & Background Overlap)
- **테두리(Border)와 배경색(Background)의 동시 중첩 절대 금지**:
  - 기존의 `background: #ffffff` + `border: 1px solid #e2e8f0` 형태의 "박스 안에 박스 안에 박스" 중첩 구조를 전면 배제합니다.
  - 경계 구분이 필요할 때는 **은은한 배경색(Off-white / Soft Gray `#f7f8fa`) 위에 순백색 서피스(`background: #ffffff`)를 올리고 섬세한 소프트 섀도우만 적용**합니다.
- **단일 얇은 디바이더(Single Divider Line)**:
  - 카드 내부의 세부 영역 구분은 박스 대신 **1px 높이의 옅은 단일 구분선(`border-top: 1px solid #f2f4f6`)**만 사용하여 시각적 노이즈를 제로화합니다.

### 1.2 비클리핑 소프트 섀도우 체계 (Non-Clipping Elevation)
- `overflow: hidden`이 걸린 부모 컨테이너로 인해 카드의 그림자가 상/하/좌/우에서 잘리는(clipping) 현상을 방지합니다.
- 컨테이너 및 그리드에 안전 패딩(`padding: 0 4px;` 또는 카드 간 갭 확보)을 두어 섀도우의 블러(`blur: 20px~30px`)가 주변 공간으로 자연스럽게 확산되도록 보장합니다.
- **섀도우 토큰**:
  - `--shadow-sm`: `0 2px 8px rgba(0, 0, 0, 0.03)`
  - `--shadow-md`: `0 4px 20px rgba(0, 0, 0, 0.04), 0 1px 3px rgba(0, 0, 0, 0.02)`
  - `--shadow-lg`: `0 8px 30px rgba(0, 0, 0, 0.06), 0 2px 6px rgba(0, 0, 0, 0.02)`

### 1.3 컬러 절제 및 단일 포인트 컬러 (Color Discipline)
- 무지개색 남발을 금지하고, 브랜드 아이덴티티를 나타내는 **토스 블루(`--primary: #3182f6`)**를 기준 포인트 컬러로 통일합니다.
- 보조 시맨틱 컬러는 성공(`--success: #00c48c`), 경고(`--warning: #ff9f00`), 위험(`--danger: #ff5252`) 3가지로만 제한하여 데이터의 의미를 명확히 전달합니다.
- 이모지 남발을 배제하고 일관된 단색 인라인 SVG 아이콘(Lucide / Tabler 스타일, `stroke-width: 2`)을 사용합니다.

---

## 2. 인터랙티브 인포그래픽 & 레이지 로드 애니메이션 (Infographics Standard)

### 2.1 다각화된 시각화 도식
- 천편일률적인 꺾은선 그래프뿐만 아니라, 데이터의 성격에 맞추어 다양한 인포그래픽을 적재적소에 배치합니다:
  - **도넛 파이 차트(Donut Chart)**: 프로세스 점유율 및 카테고리 구성비 표출 (중앙 카운터 뱃지 결합).
  - **수평 막대 차트(Horizontal Bar Chart)**: 처리량 상위 랭킹(Top 5) 및 누적 처리량 비교.
  - **스파크라인 선 그래프(Sparkline)**: 일일/월간/연간 추세 및 터치/호버 크로스헤어 인터랙션.

### 2.2 스크롤 트리거 레이지 로드 (Intersection Observer)
- 사용자가 스크롤하여 차트 영역이 뷰포트에 진입할 때 자연스럽게 차오르는 애니메이션을 적용합니다:
  - **도넛 세그먼트**: `stroke-dasharray`와 `stroke-dashoffset`이 0에서 목표치로 1.2초간 매끄럽게 회전하며 차오름.
  - **수평 막대**: 바의 너비(`width`)가 0%에서 목표 퍼센트로 부드럽게 확장.
  - **스파크라인 선**: 패스 선이 좌에서 우로 드로잉되며, 하단 그라디언트 영역이 페이드인.
  - **숫자 카운트업**: 0에서 목표 수치까지 점진적으로 숫자가 올라가는 시각적 만족감 제공.

---

## 3. 상세정보 접이식 컴포넌트 표준 (Accordion Drawer)

- **기본 접힌 상태(Collapsed by Default)**:
  - 스크립트 경로, 크론 스케줄, 수집 원천 설명, 스토리지 용량, 품질 기여도 등 보조 메타데이터는 기본으로 숨겨집니다.
  - 카드의 최우선 시각 요소는 **명칭, 상태 뱃지, 핵심 수치, 스파크라인 차트**입니다.
- **토글 인터랙션**:
  - 하단에 `[ 상세정보 ▾ ]` 버튼(Chevron Down SVG)을 배치하고, 클릭 시 180도 회전하며 세부 정보가 슬라이드 다운됩니다.
  - 내부 서피스 역시 박스 중첩 없이 단일 구분선 리스트(`display: flex; justify-content: space-between;`)로 정돈합니다.

---

## 4. 8-Point Grid 여백 체계 & 320px 모바일 완벽 대응

| 토큰명 | 크기 | 용도 |
| :--- | :---: | :--- |
| `--space-2` | 2px | 뱃지 상하 미세 인셋, 구분선 두께 |
| `--space-4` | 4px | 칩/태그 내부 상하 패딩, 아이콘-텍스트 인라인 간격 |
| `--space-6` | 6px | 뱃지 좌우 미세 패딩 |
| `--space-8` | 8px | 기본 인라인 간격, 카드 내부 요소 간 마진 |
| `--space-12` | 12px | 소형 카드 내부 패딩, 탭 버튼 간격 |
| `--space-16` | 16px | 컴포넌트 내부 기본 패딩, 카드 간 기본 갭 |
| `--space-20` | 20px | 중간 카드 패딩, 그리드 갭 |
| `--space-24` | 24px | 컨테이너 좌우 기본 여백 |
| `--space-32` | 32px | 섹션 간 수직 간격 |
| `--space-48` | 48px | 주요 섹션 헤더-컨텐츠 간격 |

- **320px 모바일 0px 가로스크롤 엄수**:
  - 도넛 차트 및 쿼터 그리드 등 다열 요소는 모바일 환경에서 1열 수직 스택으로 전환됩니다.
  - `document.documentElement.scrollWidth === document.documentElement.clientWidth`를 전 기기에서 엄격히 보장합니다.
