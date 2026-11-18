# 렛츠 패밀리 통합 디자인 시스템 (Let's Design System, LDS v1.0.0)
> **최종 개정일**: 2026-11-18  
> **기준 레퍼런스**: 렛츠캘린더 (`/calendar`), 뉴스보드 인물 상세 페이지 (`/news/person/`), Apple HIG, Toss Simplicity, Supabase Design, Naver Design System  
> **적용 대상**: `Let's Law`, `Let's Insu`, `Let's People`, `Let's Asset`, `Let's Art`, `Let's View`, `MeatTracker`, `Let's Hub` 등 생태계 전 서비스

---

## 1. 디자인 철학 및 인간 중심 원칙 (Human-Centered Core Principles)

### 1.1 힉스의 법칙 (Hick's Law) & 선택지 최소화
- 사용자가 결정을 내리는 시간은 선택지의 수와 복잡성에 비례하여 증가합니다.
- 복잡한 법률·금융·인물 데이터를 표출할 때 한 화면에 모든 옵션을 나열하지 않고, **가장 중요한 1차 판단 지표(Hero Metric)를 최상단에 배치**하고 부차적 옵션은 접거나 탭/모달로 분리합니다.

### 1.2 피츠의 법칙 (Fitts's Law) & 터치 친화적 상호작용
- 모바일(320px~430px) 및 터치 디바이스에서 모든 인터랙티브 요소(버튼, 탭, 칩)의 **최소 터치 타깃 영역은 44×44px**을 보장합니다.
- 중요한 액션 버튼(예: 과실비율 산정, 합의금 계산, 필모그래피 열람)은 엄지손가락이 닿기 쉬운 하단 썸 존(Thumb Zone) 또는 카드 하단 전폭으로 배치합니다.

### 1.3 인공지능 스타일(Impeccable / Cold Flat AI) 탈피 및 휴먼 터치 (Human Touch)
- AI가 생성한 기계적이고 삭막한 평면 디자인, 획일적인 보라색 그라디언트를 일절 배제합니다.
- 섬세한 곡률(`border-radius: 12px~16px`), 미세한 앰비언트 섀도우(`rgba(15, 23, 42, 0.05~0.08)`), 정보 간의 명확한 시각적 위계(Primary/Secondary/Tertiary 텍스트), 마우스 호버 시 텐션감 있는 마이크로 인터랙션(`transform: translateY(-2px) cubic-bezier(0.16, 1, 0.3, 1)`)을 부여합니다.

---

## 2. 8-Point Grid 여백 체계 (Spacing Hierarchy)

모든 레이아웃 간격, 패딩, 마진, 아이콘 규격은 **8의 배수**를 절대 원칙으로 사용합니다. 8px 미만의 미세 간격(뱃지 패딩, 태그 인셋 등)은 반드시 **짝수(2px, 4px, 6px)**를 유지합니다.

| 토큰명 | 크기 | 용도 |
| :--- | :---: | :--- |
| `--space-2` | 2px | 뱃지 상하 미세 인셋, 구분선 두께 |
| `--space-4` | 4px | 칩/태그 내부 상하 패딩, 아이콘-텍스트 인라인 간격 |
| `--space-6` | 6px | 뱃지 좌우 미세 패딩 |
| `--space-8` | 8px | 기본 인라인 간격, 카드 내부 요소 간 마진 |
| `--space-12` | 12px | 소형 카드 내부 패딩, 탭 버튼 간격 |
| `--space-16` | 16px | 컴포넌트 내부 기본 패딩, 카드 간 기본 갭 |
| `--space-20` | 20px | 중간 카드 패딩, 그리드 갭 |
| `--space-24` | 24px | 컨테이너 좌우 기본 여백 (모바일/태블릿) |
| `--space-32` | 32px | 섹션 간 수직 간격 |
| `--space-40` | 40px | 대형 블록 상하 마진 |
| `--space-48` | 48px | 주요 섹션 헤더-컨텐츠 간격 |
| `--space-64` | 64px | 페이지 단위 대구분 수직 여백 |

---

## 3. 반응형 브레이크포인트 & 세로 적층(Stacking) 규칙

### 3.1 320px 모바일 절대 지원 (320px ~ 1440px+)
- 최소 지원 가로폭: **320px** (iPhone SE 1세대 및 폴더블 외부 화면 대응).
- 최대 컨테이너 폭: **1440px** (`margin: 0 auto;`).

### 3.2 4-2-1 컬럼 반응형 전환 및 억지 줄바꿈 극단 배제
- **데스크톱 (≥ 1024px)**: 가로 4단 (4-Column) 그리드.
- **태블릿 (640px ~ 1023px)**: 가로 2단 (2-Column) 그리드.
- **모바일 (320px ~ 639px)**: 가로 1단 (1-Column) 그리드.
- **세로 적층 (Vertical Stacking) 원칙**:
  - 가로폭이 좁아질 때 글자가 좁은 칸에 갇혀 2~3글자 단위로 흉하게 줄바꿈(`word-break: break-all`로 인한 자모 분리 등)되는 것을 극도로 금지합니다.
  - 가로로 배치되었던 메트릭(수집량, 처리속도, 스케줄 등)은 가로폭 축소 시 즉시 `flex-direction: column`으로 세로 적층되어 **글줄의 온전한 형태와 가독성**을 유지합니다.

---

## 4. 스크롤 통제 & 가로 캐러셀(Swipe Carousel) 표준

### 4.1 불필요한 세로 스크롤 지양
- 여백만 넓고 내용이 빈약하여 무의미하게 길어지는 세로 스크롤을 억제하고, 카드 내부 정보 밀도를 균형 있게 배치합니다.

### 4.2 브라우저 가로 스크롤(Horizontal Window Scroll) 영구 차단
- 컨텐츠가 뷰포트 바깥으로 튀어나와 브라우저 전체에 가로 스크롤바가 생기는 현상은 **결함(Bug)**으로 규정하며 `overflow-x: hidden` 및 유동 폭(`max-width: 100%`)으로 완전 통제합니다.

### 4.3 가로 나열 시 '무스크롤바 마우스 드래그 / 터치 스와이프 캐러셀' 사용
- 탭 메뉴, 칩 목록, 횡단 카드 목록 등 가로 나열이 필수적인 경우:
  - 브라우저 기본 스크롤바는 `scrollbar-width: none;` 및 `::-webkit-scrollbar { display: none; }`으로 완전 숨김 처리.
  - 마우스 클릭 드래그(`cursor: grab / grabbing`) 및 모바일 터치 플릭(`touch-action: pan-x pan-y`)으로 부드럽게 스냅 스크롤되는 캐러셀 구조 채택.

---

## 5. 타이포그래피 & WCAG 2.1 접근성 (Typography & Color Contrast)

### 5.1 기본 글꼴
- **국문/영문 표준**: `Pretendard Variable`, `Pretendard`, -apple-system, BlinkMacSystemFont, system-ui, sans-serif.
- **숫자 데이터**: `font-variant-numeric: tabular-nums;` (표/차트 수치 정렬).

### 5.2 타이포그래피 스케일 토큰
| 토큰 | 크기 | 행간(Line-Height) | 자간(Letter-Spacing) | 기본 용도 |
| :--- | :---: | :---: | :---: | :--- |
| `--fs-display` | 32px ~ 40px | 1.2 | -0.03em | 대시보드 메인 히어로 헤드라인 |
| `--fs-2xl` | 24px ~ 28px | 1.25 | -0.025em | 서비스 대제목 (H1) |
| `--fs-xl` | 20px ~ 22px | 1.3 | -0.02em | 섹션 헤딩 (H2) |
| `--fs-lg` | 17px ~ 18px | 1.4 | -0.015em | 카드 타이틀 (H3) |
| `--fs-md` | 14px ~ 15px | 1.5 | -0.01em | 기본 본문 텍스트 (Body) |
| `--fs-sm` | 12px ~ 13px | 1.45 | 0 | 캡션, 보조 설명, 스펙 키값 |
| `--fs-xs` | 10px ~ 11px | 1.3 | +0.02em | 상태 뱃지, 단위, 타임스탬프 |

### 5.3 WCAG 2.1 AA/AAA 4.5:1 이상 명도 대비율 준수
- 일반 텍스트(`--text-primary: #0f172a`): 배경 `#ffffff` 대비 **15.8:1** (AAA 기준 초과 달성).
- 보조 텍스트(`--text-muted: #475569`): 배경 `#ffffff` 대비 **5.8:1** (AA 기준 충족).
- 뱃지/버튼: 연한 배경(`--bg-soft`)에 짙은 원색(`--text-bold`)을 결합하여 가독성 100% 확보 (예: 에메랄드 배경 `#ecfdf5` + 텍스트 `#065f46`).

---

## 6. 서비스별 브랜드 패밀리룩 & 컬러 시스템

전체 패밀리가 일관된 섀도우, 폰트, 그리드 레이아웃을 공유하면서, 각 서비스 고유의 도메인 성격을 직관적으로 인지할 수 있는 시그니처 컬러를 부여합니다.

| 서비스 ID | 서비스명 | 시그니처 색상 | 소프트 배경색 | 대표 도메인 |
| :--- | :--- | :---: | :---: | :--- |
| `people` | **렛츠피플 (Let's People)** | `#e11d48` (Rose) | `#ffe4e6` | 인물·미디어 PD·필모그래피 |
| `asset` | **렛츠에셋 (Let's Asset)** | `#4f46e5` (Indigo) | `#eef2ff` | 100년 금융·SEC·재무관리 |
| `law` | **렛츠로 (Let's Law)** | `#2563eb` (Blue) | `#eff6ff` | 대법원 판례·3D 교통사고 |
| `insu` | **렛츠인슈 (Let's Insu)** | `#059669` (Emerald) | `#ecfdf5` | 46년 약관·손해사정 반박 |
| `art` | **렛츠아트 (Let's Art)** | `#d97706` (Amber) | `#fef3c7` | 고전 명화·현대미술·건축 |
| `cultureflow` | **컬처플로우 (CultureFlow)** | `#0284c7` (Sky) | `#f0f9ff` | 공연·전시·문화예술 캘린더 |
| `view` | **렛츠뷰 (Let's View)** | `#06b6d4` (Cyan) | `#ecfeff` | 전국 1.8만 교통/재난 영상망 |
| `meattracker` | **미트트래커 (MeatTracker)** | `#ef4444` (Red) | `#fef2f2` | 축산물 이력·도소매 시세 |
| `camp` | **렛츠캠프 (Let's Camp)** | `#10b981` (Teal) | `#d1fae5` | 전국 캠핑장·글램핑 원장 |
| `calendar` | **렛츠캘린더 (Let's Calendar)** | `#6366f1` (Violet) | `#e0e7ff` | 일정 조율·정산·모여라 달력 |

---

## 7. 커스텀 컴포넌트 시스템 (OS 시스템 UI 영구 퇴출)

OS나 브라우저마다 흉하게 다르게 렌더링되는 기본 네이티브 UI(셀렉트 박스, 기본 스크롤바, 기본 팝업 alert, 기본 라디오/체크박스)의 사용을 **전면 금지**합니다.

1. **커스텀 셀렉트 / 드롭다운**: 라운드 박스(`border-radius: 10px`), 슬레이트 보더, SVG 셰브론 아이콘으로 통일.
2. **커스텀 라디오 / 칩**: 탭 필터 칩 스타일로 디자인하여 터치 반경 확장 및 명확한 액티브 배경색 피드백.
3. **커스텀 모달 / 다이얼로그**: 백드롭 블러(`backdrop-filter: blur(8px); background: rgba(15, 23, 42, 0.6)`), 부드러운 스케일 인 애니메이션, 우측 상단 순정 닫기(`✕`) 버튼.
4. **커스텀 툴팁**: 다크 슬레이트 솔리드 박스(`background: #0f172a; color: #ffffff`), 미세 섀도우, 마우스 추적 부드러운 트랜지션.

---

## 8. 모바일 PWA & iOS Safari Safe Area 여백 관리

### 8.1 PWA 뷰포트 피트 설정
```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover, interactive-widget=resizes-content">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
```

### 8.2 iOS 상단 인디케이터 & 하단 홈핸들 세이프 에어리어 (Safe Area Inset)
- 아이폰 사파리 또는 홈 화면 PWA 전체화면 실행 시, 상단 다이내믹 아일랜드/노치나 하단 홈 핸들에 컨텐츠가 가려지지 않도록 컨테이너에 세이프 에어리어 환경 변수를 필수로 바인딩합니다.
```css
body {
  padding-top: max(20px, env(safe-area-inset-top));
  padding-bottom: max(24px, env(safe-area-inset-bottom));
  padding-left: max(16px, env(safe-area-inset-left));
  padding-right: max(16px, env(safe-area-inset-right));
}
```

### 8.3 웹 푸시 알림 (Web Push Notification) 센터 표준
- PWA의 핵심 가치는 **무인 수집/분석 이상의 실시간 푸시 알림**에 있습니다.
- 모든 서비스 헤더에 **알림 벨 아이콘 (`🔔`)**과 인디케이터 점(`dot`)을 표준 배치하고, 클릭 시 최근 수집 경보(Caution), 이상징후 알림을 확인하고 브라우저 푸시 권한을 1클릭으로 등록/해제할 수 있는 통합 알림 센터 드로어를 구비합니다.

---

## 9. 소셜 공유 에셋 & 오픈그래프 (OpenGraph Protocol) 표준

모든 렛츠 패밀리 서비스는 카카오톡, 슬랙, 트위터, 페이스북 공유 시 브랜드를 온전히 드러낼 수 있도록 다음 규격을 필수로 구비합니다.

1. **오픈그래프 썸네일 (`og:image`)**: `1200 × 630px` (2:1 비율), 100KB 미만 최적화 WebP/JPG.
2. **파비콘 & 앱 아이콘**:
   - `favicon.ico` & `favicon-32x32.png`
   - `apple-touch-icon.png` (`180 × 180px`, 라운드 코너 자동 적용 고려)
3. **메타 태그 템플릿**:
```html
<meta property="og:type" content="website">
<meta property="og:site_name" content="서비스 국문 명칭">
<meta property="og:title" content="핵심 가치 제안 타이틀">
<meta property="og:description" content="사용자가 얻을 수 있는 혜택 중심의 2줄 요약 설명">
<meta property="og:image" content="https://pyw31337.github.io/{service}/assets/og-thumb.png">
```

---

## 10. 통합 슈퍼 플랫폼 (Unified Super-Platform) 확장 아키텍처

1. **공통 URN 온톨로지 네임스페이스**:
   - 인물: `urn:people:person:{id}`
   - 판례: `urn:law:precedent:{id}`
   - 약관: `urn:insu:policy:{id}`
   - 금융: `urn:asset:ticker:{symbol}`
   - 예술: `urn:art:work:{id}`
   - 영상: `urn:view:channel:{cctv_id}`
   - 시세: `urn:meat:item:{trace_id}`
2. **글로벌 옴니서치 (Global Omnibox Search Bar)**:
   - 렛츠허브 상단에 통합 검색창을 구비하여 사용자가 "교통사고", "자하 하디드", "삼성전자", "한우 시세" 등을 입력하면 15개 서비스 전체의 URN 엔티티를 즉시 교차 탐색하여 다이렉트 딥링크로 안내합니다.
