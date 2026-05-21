# AGENTS.md

## 프로젝트 개요

Awake는 macOS에서 사용자가 선택한 실행 중인 작업이 끝날 때까지 Mac이 잠자기에 들어가지 않도록 돕는 메뉴바 앱이다. 사용자는 앱 실행, 단축키, 메뉴바 액션으로 현재 열려 있는 앱/윈도우를 보고, 유지할 대상을 선택한 뒤 바로 보호 세션을 시작한다.

핵심 유스케이스는 터미널, tmux, Codex, 빌드, 업로드, 렌더링처럼 시간이 걸리는 작업을 MacBook 화면 꺼짐이나 일반 유휴 잠자기 때문에 중단하지 않는 것이다. 단, MacBook 덮개 닫힘은 macOS와 하드웨어 정책의 영향을 크게 받으므로 MVP에서는 "덮개 닫힘에서도 항상 실행 보장"이 아니라 "가능한 전원 assertion 범위를 명확히 검증하고 안내"하는 제품으로 설계한다.

제품 문서는 `docs/`에 있고, 개발 문서는 `docs/development/`에 있다. 구현 전에는 반드시 관련 문서를 먼저 읽고, 문서와 충돌하는 결정을 임의로 넣지 않는다.

## Codex 작업 원칙

- 제품 흐름은 `docs/mvp-spec.md`를 기준으로 한다.
- 개발 구조는 `docs/development/architecture.md`를 기준으로 한다.
- macOS 전원 제어 정책은 `docs/development/power-management.md`를 기준으로 한다.
- 윈도우/프로세스 선택 동작은 `docs/development/window-selection.md`를 기준으로 한다.
- 작업을 시작하기 전에 관련 파일을 읽고 기존 문서와 구현 패턴을 따른다.
- 기능 구현은 작고 검증 가능한 단위로 나눈다.
- 사용자 요청과 무관한 리팩터링은 하지 않는다.
- 구현 중 제품 문서와 기술 문서가 어긋나면 코드만 바꾸지 말고 문서도 함께 갱신한다.
- macOS 권한, 전원 assertion, 실행 중 앱 감지, 메뉴바 상태 표시는 사용자 신뢰에 직접 영향을 주므로 실패 상태를 반드시 고려한다.
- 덮개 닫힘, 배터리 절약 모드, 회사 관리 장비 정책, 외부 전원/디스플레이 조건은 환경별 차이가 있으므로 하드코딩된 보장을 문구로 넣지 않는다.

## 권장 기술 스택

- Language: Swift
- UI: SwiftUI + AppKit
- App shell: macOS menu bar app
- Power management: IOKit power assertions
- App/window discovery: AppKit, CoreGraphics Window Services, Accessibility where needed
- Persistence: UserDefaults first, JSON session log later if needed
- Tests: XCTest

## 구현 우선순위

1. 앱 셸과 메뉴바 상태 표시
2. 보호 세션 상태 모델
3. 전원 assertion 생성/해제
4. 현재 실행 중인 앱 목록 표시
5. 선택 대상 기반 보호 세션 시작/종료
6. 종료 감지와 자동 assertion 해제
7. 권한 요청 및 실패 상태 안내
8. 단축키
9. 최근 세션 기록과 안정화

## MVP에서 하지 않을 것

- private API로 덮개 닫힘 잠자기를 우회
- 커널 확장 또는 시스템 확장 설치
- 원격 제어 기능
- 작업 내용 감시나 터미널 출력 파싱
- 프로세스 강제 재시작
- 클라우드 동기화
- 팀 관리 기능

## 문서 목록

- `README.md`: 프로젝트 진입점
- `docs/product-idea.md`: 제품 아이디어
- `docs/mvp-spec.md`: MVP 제품 명세
- `docs/roadmap.md`: 제품 로드맵
- `docs/development/tech-stack.md`: 기술 스택
- `docs/development/architecture.md`: 앱 아키텍처
- `docs/development/feature-specs.md`: 기능별 개발 명세
- `docs/development/window-selection.md`: 앱/윈도우 선택 정책
- `docs/development/power-management.md`: macOS 전원 관리 정책
- `docs/development/permissions.md`: macOS 권한 정책
- `docs/development/data-and-storage.md`: 데이터와 저장 구조
- `docs/development/implementation-plan.md`: 구현 순서
- `docs/development/codex-workflow.md`: Codex 작업 방식
- `docs/development/testing.md`: 테스트 전략
