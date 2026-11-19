# Let's 허브 운영 관제 보강 기록

## 현재 부족했던 점

1. **정적 성공률 중심**: `master_ecosystem_pulse.json`의 전체 점수와 파이프라인 수는 구조를 설명하지만, 최근 workflow 실패·stale heartbeat·권한 오류를 드러내지 못했습니다.
2. **서비스와 자동화 장치가 분리되지 않음**: 61개 장치를 볼 수 있어도 어떤 서비스가 실제로 주의 대상인지 한 번에 판단하기 어려웠습니다.
3. **다음 행동이 없음**: 이슈·workflow·저장소 링크가 상태와 연결되지 않아 운영자가 다시 검색해야 했습니다.
4. **운영 데이터의 신선도 표시 부족**: 집계 시각과 원본별 마지막 갱신 시각이 한 화면에 없었습니다.
5. **quota·handoff·Mac mini 상태가 별도 문맥**: 용량, 로컬 heartbeat, GitHub Actions가 동일한 우선순위 체계로 묶이지 않았습니다.

## 이번 보강

- `data/operations_status.json`을 추가해 서비스 상태를 `healthy / degraded / blocked`로 분리했습니다.
- 서비스별 마지막 갱신 시각, 상세 원인, 다음 조치, Pages·저장소 링크를 함께 표시합니다.
- `전체 / 주의만` 필터로 장애 후보만 즉시 좁힐 수 있습니다.
- 지금 처리할 일(incident)을 영향도 순으로 표시합니다.
- quota·Mac mini heartbeat·handoff·Pages 배포를 별도 운영 check로 표시합니다.

## 다음 단계

- GitHub Actions에서 운영 snapshot을 자동 생성해 수동 JSON 갱신을 제거합니다.
- workflow run의 `conclusion`, issue open 상태, commit freshness를 서비스별로 정규화합니다.
- private repository는 별도 서버/Worker에서 토큰을 보관하고, Pages에는 최소 공개 상태만 전달합니다.
- 상태가 2회 연속 실패할 때만 `degraded`에서 `blocked`로 승격하는 정책을 추가합니다.
