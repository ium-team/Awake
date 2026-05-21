# 테스트 전략

## 단위 테스트

- `SessionController` 상태 전환
- 중복 시작/종료 처리
- 선택 대상이 모두 종료되었을 때 자동 종료 판단
- 설정 기본값

## 통합 테스트

- assertion 생성/해제 wrapper
- target monitor와 session controller 연결
- 앱 목록 provider snapshot 생성

## 수동 테스트

- 세션 시작 후 `pmset -g assertions` 확인
- 세션 종료 후 assertion 제거 확인
- 선택한 앱 종료 시 자동 해제 확인
- Awake 앱 종료 시 assertion 해제 확인
- 디스플레이 꺼짐 상태에서 작업 유지 확인
- 배터리/전원 연결 상태별 동작 확인

## 덮개 닫힘 검증

MVP 개발 중 다음 환경을 분리해 기록한다.

- MacBook 단독, 배터리
- MacBook 단독, 전원 연결
- 외부 디스플레이 연결
- 외부 전원과 외부 입력 장치 연결
- 회사 관리 장비 또는 MDM 적용 장비

결과는 제품 보장 문구가 아니라 환경별 참고 정보로만 사용한다.

## 회귀 테스트 포인트

- active 세션이 남아 있는데 assertion이 없는 상태
- assertion은 남아 있는데 UI는 idle인 상태
- 선택 대상이 종료되었는데 세션이 유지되는 상태
- 권한이 없을 때 선택 화면이 비어 보이는 상태
- 앱 종료 후 assertion이 남는 상태
