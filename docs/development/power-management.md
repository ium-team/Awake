# macOS 전원 관리 정책

## 목표

Awake는 보호 세션이 active인 동안 macOS의 일반 유휴 잠자기를 막는다. 선택 대상이 종료되면 전원 assertion을 즉시 해제한다.

## 사용할 API

MVP에서는 IOKit power assertion을 사용한다.

- system idle sleep 방지: 선택 대상 작업이 진행되는 동안 시스템 잠자기를 방지
- display sleep 방지: 설정으로 선택 가능

## 덮개 닫힘 정책

MacBook 덮개 닫힘은 일반 유휴 잠자기와 다르다. 앱 수준 assertion으로 모든 조건에서 계속 실행을 보장하지 않는다.

문서와 UI에서는 다음처럼 표현한다.

- "화면이 꺼지거나 일반 잠자기에 들어가는 것을 막습니다."
- "덮개 닫힘은 Mac 설정과 연결된 전원/디스플레이 환경에 따라 달라질 수 있습니다."
- "Awake는 private API나 시스템 우회 방식을 사용하지 않습니다."

## assertion 생명주기

1. 세션 시작 직전 assertion 생성
2. 생성 성공 시 세션 active 전환
3. 세션 active 동안 assertion ID 유지
4. 수동 종료, 자동 종료, 앱 종료 시 assertion 해제
5. 해제 후 assertion ID 제거

## 실패 상태

- assertion 생성 실패
- assertion 해제 실패
- 중복 assertion 생성 시도
- 앱 비정상 종료로 assertion 해제 누락 가능성

해제 실패는 로그로 남기고 사용자에게 현재 상태를 표시한다. 중복 생성 시도는 기존 assertion을 재사용하거나 먼저 해제한 뒤 재생성한다.

## 검증 명령

개발 중에는 macOS의 `pmset -g assertions`로 assertion이 실제로 잡혔는지 확인한다.

```bash
pmset -g assertions
```

검증 포인트:

- 세션 시작 후 Awake 관련 assertion이 보인다.
- 세션 종료 후 assertion이 사라진다.
- 앱 종료 후 assertion이 사라진다.
