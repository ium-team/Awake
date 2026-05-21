# 아키텍처

## 구성

- `AwakeApp`: 앱 진입점과 메뉴바 앱 생명주기
- `MenuBarController`: 메뉴바 아이콘, 메뉴, active 상태 표시
- `SelectionWindowController`: 보호 대상 선택 화면 표시
- `RunningAppProvider`: 실행 중 앱과 윈도우 목록 수집
- `SessionController`: 보호 세션 상태 전환
- `PowerAssertionController`: IOKit assertion 생성/해제
- `TargetMonitor`: 선택 대상 생존 여부 감시
- `PermissionController`: Accessibility 등 권한 상태 확인
- `SettingsStore`: 기본 설정 저장

## 데이터 흐름

1. 사용자가 메뉴바 또는 단축키로 선택 화면을 연다.
2. `RunningAppProvider`가 실행 중 앱과 윈도우 후보를 만든다.
3. 사용자가 대상을 선택한다.
4. `SessionController`가 `PowerAssertionController`에 assertion 생성을 요청한다.
5. assertion 생성이 성공하면 `TargetMonitor`가 선택 대상 감시를 시작한다.
6. 대상이 모두 종료되면 `SessionController`가 세션 종료를 요청한다.
7. `PowerAssertionController`가 assertion을 해제한다.
8. `MenuBarController`가 idle 상태로 돌아간다.

## 상태 소유권

`SessionController`가 세션 상태의 단일 소유자다. UI는 세션 상태를 표시하고 사용자 액션을 전달할 뿐, assertion을 직접 생성하거나 해제하지 않는다.

## 실패 처리

- assertion 생성 실패: 세션을 active로 바꾸지 않고 오류 표시
- 앱 목록 수집 실패: 선택 화면에 오류와 재시도 제공
- 권한 부족: 가능한 범위의 목록을 보여주고 권한 요청 경로 제공
- 앱 종료 중 assertion 남음: 앱 종료 hook에서 해제 시도

## 구현 원칙

- 전원 assertion ID는 한 곳에서만 보관한다.
- assertion 생성과 해제는 idempotent하게 만든다.
- 감시 타이머는 세션 종료 시 반드시 멈춘다.
- UI는 target snapshot을 다루고, 실제 생존 확인은 PID/process identifier 기준으로 한다.
