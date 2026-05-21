# 앱/윈도우 선택 정책

## 목표

사용자가 "지금 끝나면 안 되는 것"을 빠르게 고를 수 있게 한다. 현재 제품은 윈도우를 UI에 보여주되, 세션 유지 판단은 앱 프로세스 단위로 한다.

## 데이터 소스

- `NSWorkspace.shared.runningApplications`: 실행 중 앱 목록
- CoreGraphics Window Services: 화면에 표시 가능한 윈도우 정보
- Accessibility: 윈도우 제목과 상세 정보가 추가로 필요할 때 사용

## 목록 포함 기준

- 일반 사용자 앱을 우선 표시한다.
- background-only 앱은 기본적으로 숨긴다.
- 번들 이름, 아이콘, PID가 있는 앱을 우선한다.
- Dock, Finder, System Settings 같은 시스템 앱은 표시하되 후순위로 둔다.

## 윈도우 처리

현재 윈도우 선택은 사용자 이해를 돕는 UI 단위다. 실제 감시는 해당 윈도우를 소유한 앱 프로세스를 기준으로 한다.

이유:

- 많은 앱이 윈도우를 닫아도 프로세스는 계속 살아 있다.
- 일부 앱은 윈도우 제목이나 ID가 자주 바뀐다.
- Accessibility 권한 없이 윈도우 상세 추적이 제한될 수 있다.

## 선택 대상 모델

- `app`: bundle identifier, localized name, pid
- `window`: window id, title, owner pid, owner app name

세션 저장 시에는 최소한 PID와 bundle identifier를 저장한다. PID가 재사용될 수 있으므로, 생존 확인 시 process start time을 얻을 수 있으면 함께 비교한다.

## 종료 판단

현재:

- 선택된 앱 PID가 모두 사라지면 세션 종료
- 선택된 윈도우는 owner PID 기준으로 처리

개선 방향:

- 윈도우 ID 소멸 기준 종료
- 특정 터미널 탭/프로세스 트리 기준 종료
- 앱별 종료 판단 전략
