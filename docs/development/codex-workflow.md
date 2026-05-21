# Codex 개발 워크플로우

## 시작 전

작업 전에 관련 문서를 읽는다.

- 제품 동작: `docs/mvp-spec.md`
- 아키텍처: `docs/development/architecture.md`
- 전원 관리: `docs/development/power-management.md`
- 윈도우 선택: `docs/development/window-selection.md`

## 작업 방식

- 변경 범위를 작게 잡는다.
- 전원 assertion과 세션 상태는 테스트 가능한 타입으로 분리한다.
- UI에서 직접 시스템 API를 호출하지 않는다.
- macOS 환경별 차이를 숨기지 않는다.
- 문서와 구현이 달라지면 같은 작업에서 문서를 갱신한다.

## 검증

기능 구현 후 가능한 검증을 실행한다.

- 빌드
- XCTest
- assertion 수동 확인
- 앱 종료 후 assertion 해제 확인

## 금지

- private API 사용
- 사용자가 요청하지 않은 대규모 리팩터링
- 덮개 닫힘 동작을 보장하는 문구 추가
- 권한 실패를 조용히 무시
- assertion 해제 없이 세션 종료
