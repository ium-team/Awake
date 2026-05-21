# Awake

Awake는 Mac에서 오래 걸리는 작업이 끝날 때까지 시스템 잠자기를 막아주는 macOS 메뉴바 앱이다. 사용자는 현재 실행 중인 앱이나 윈도우를 선택하고 보호 세션을 시작한다. 선택한 대상이 종료되면 Awake가 자동으로 전원 유지 상태를 해제한다.

대표 시나리오는 터미널/tmux에서 Codex를 돌리거나, 빌드, 업로드, 다운로드, 렌더링처럼 사용자가 자리를 비운 뒤에도 끝까지 진행되어야 하는 작업이다.

중요한 제품 원칙: Awake는 macOS가 제공하는 전원 assertion을 사용해 일반 유휴 잠자기와 디스플레이 잠자기를 제어한다. MacBook 덮개 닫힘은 macOS, 하드웨어, 외부 전원, 외부 디스플레이, 회사 관리 정책에 따라 다르게 동작할 수 있으므로 MVP에서는 이를 무조건 보장하지 않는다.

## 문서

- [제품 아이디어](docs/product-idea.md)
- [MVP 명세서](docs/mvp-spec.md)
- [로드맵](docs/roadmap.md)

## 개발 문서

- [기술 스택](docs/development/tech-stack.md)
- [아키텍처](docs/development/architecture.md)
- [기능별 개발 명세](docs/development/feature-specs.md)
- [앱/윈도우 선택 정책](docs/development/window-selection.md)
- [macOS 전원 관리 정책](docs/development/power-management.md)
- [macOS 권한 정책](docs/development/permissions.md)
- [데이터와 저장 구조](docs/development/data-and-storage.md)
- [구현 계획](docs/development/implementation-plan.md)
- [Codex 개발 워크플로우](docs/development/codex-workflow.md)
- [테스트 전략](docs/development/testing.md)
- [Codex 작업 지침](AGENTS.md)

## MVP 핵심 범위

- 메뉴바 앱으로 실행
- 단축키 또는 메뉴바에서 보호 대상 선택 화면 열기
- 현재 실행 중인 앱/윈도우 목록 표시
- 사용자가 하나 이상의 대상을 선택
- 선택 즉시 보호 세션 시작
- 보호 세션 중 macOS 전원 assertion 유지
- 선택한 대상이 모두 종료되면 자동 해제
- 사용자가 수동으로 세션 종료 가능
- 권한 부족 또는 환경 제약을 명확하게 표시

## 현재 구현 상태

- SwiftPM 기반 macOS 메뉴바 앱
- 메뉴바 상태 아이콘
- `command+shift+a` 전역 단축키
- 실행 중 앱 목록과 감지 가능한 윈도우 수 표시
- 다중 앱 선택
- IOKit 기반 system idle sleep 방지
- 설정에서 display sleep 방지 선택 가능
- 로그인 시 자동 실행 설정
- 선택한 앱 프로세스가 모두 종료되면 자동 해제
- 자동 종료 알림
- `.app` 번들 생성 스크립트

## 개발 실행

개발 실행:

```bash
swift run Awake
```

앱 번들 생성:

```bash
chmod +x scripts/build-app.sh
scripts/build-app.sh
open build/Awake.app
```

기본 단축키:

- 보호 대상 선택 창 열기: `command+shift+a`

전원 assertion 확인:

```bash
pmset -g assertions
```
