# macOS 전원 관리 정책

## 목표

Awake는 보호 세션이 active인 동안 macOS의 일반 유휴 잠자기를 막는다. 선택 대상이 종료되면 전원 assertion을 즉시 해제한다.

## 사용할 API

Awake는 IOKit power assertion을 사용한다.

- system idle sleep 방지: `kIOPMAssertPreventUserIdleSystemSleep`로 선택 대상 작업이 진행되는 동안 사용자 유휴로 인한 시스템 잠자기를 방지
- display sleep 방지: `kIOPMAssertPreventUserIdleDisplaySleep`로 기본 활성화, 설정에서 끌 수 있음
- closed-display best-effort: `kIOPMAssertNetworkClientActive`로 macOS가 허용하는 AC/closed-display 환경에서 네트워크와 시스템 활동 유지를 보조
- lid-closed 강제 유지: 사용자가 설정을 켜면 최초 1회 관리자 권한으로 LaunchDaemon helper를 설치한다. helper는 세션 신호 파일을 감시하고, 세션 동안 `pmset -a disablesleep 1`을 적용한 뒤 신호 파일이 사라지면 `pmset -a disablesleep 0`으로 복구한다.

## 덮개 닫힘 정책

MacBook 덮개 닫힘은 일반 유휴 잠자기와 다르다. 앱 수준 assertion만으로는 단독 배터리 + 덮개 닫힘을 막을 수 없다. Awake의 lid-closed 모드는 시스템 전원 설정을 바꾸는 고급 모드로 이 문제를 해결한다.

`pmset disablesleep`은 시스템 전체 설정이며 관리자 권한이 필요하다. 매번 켜고 끌 때 비밀번호를 묻지 않도록 최초 1회 설치한 helper가 세션 신호 파일을 감시하고 복구한다. 설정이 남으면 Mac이 정상적으로 잠자기에 들어가지 않을 수 있으므로 세션 종료, 수동 종료, 앱 종료 시 신호 파일을 제거하고, 메뉴바에 수동 복구 액션을 항상 제공한다.

문서와 UI에서는 다음처럼 표현한다.

- "세션 동안 덮개 닫힘 sleep을 막기 위해 관리자 권한으로 macOS sleep 설정을 변경합니다."
- "최초 1회 helper 설치를 승인하면 이후 세션 시작/종료는 반복 비밀번호 없이 처리됩니다."
- "lid-closed 세션 중 실제 덮개가 닫히면 화면보호기를 실행합니다."
- "가방이나 밀폐된 공간에서는 사용하지 마세요."

## assertion 생명주기

1. 세션 시작 직전 assertion 생성
2. 생성 성공 시 세션 active 전환
3. 세션 active 동안 assertion ID 유지
4. lid-closed 모드가 켜져 있으면 helper 설치 여부를 확인하고 세션 신호 파일 생성
5. 세션 중 display sleep 방지, closed-display best-effort, lid-closed 설정이 변경되면 active 세션에 즉시 반영
6. helper가 신호 파일을 보고 `pmset -a disablesleep 1` 적용
7. 수동 종료, 자동 종료, 앱 종료 시 assertion 해제 및 신호 파일 제거
8. helper가 `pmset -a disablesleep 0` 복구
9. 해제 후 assertion ID 제거

## 실패 상태

- assertion 생성 실패
- assertion 해제 실패
- 관리자 권한 거부 또는 `pmset disablesleep` 실패
- 앱 비정상 종료로 sleep disabled 설정 복구 누락 가능성
- 중복 assertion 생성 시도
- 앱 비정상 종료로 assertion 해제 누락 가능성

해제 실패는 로그로 남기고 사용자에게 현재 상태를 표시한다. 중복 생성 시도는 기존 assertion을 재사용하거나 먼저 해제한 뒤 재생성한다. sleep disabled 설정 복구 누락에 대비해 메뉴바의 `Restore macOS Sleep`을 제공한다.

## 검증 명령

개발 중에는 macOS의 `pmset -g assertions`로 assertion이 실제로 잡혔는지 확인한다.

```bash
pmset -g assertions
```

검증 포인트:

- 세션 시작 후 Awake 관련 assertion이 보인다.
- lid-closed 모드 세션 시작 후 `pmset -g`에서 `SleepDisabled 1`이 보인다.
- 세션 종료 후 assertion이 사라진다.
- 세션 종료 후 `pmset -g`에서 `SleepDisabled 0`이 보인다.
- 앱 종료 후 assertion이 사라진다.
