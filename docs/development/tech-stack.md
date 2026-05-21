# 기술 스택

## 기본 선택

- Language: Swift
- UI: SwiftUI + AppKit
- App model: macOS menu bar app
- Power management: IOKit power assertions
- Window discovery: AppKit `NSWorkspace`, CoreGraphics Window Services
- Accessibility: 윈도우 제목/상세 정보가 필요할 때만 사용
- Persistence: `UserDefaults`
- Tests: XCTest

## 이유

Swift와 AppKit은 macOS 전원 관리, 메뉴바 앱, 실행 중 앱 감지, 권한 상태 확인에 가장 직접적으로 접근할 수 있다. SwiftUI는 선택 화면과 설정 UI를 빠르게 만들기 좋고, AppKit은 메뉴바/윈도우/시스템 이벤트 처리에 필요하다.

## 초기 프로젝트 형태

초기에는 Swift Package보다 Xcode macOS App 프로젝트가 권한, 번들 식별자, 메뉴바 앱 설정을 다루기 쉽다. CLI 테스트가 필요한 전원 assertion 로직은 별도 Swift 타입으로 분리해 XCTest에서 검증한다.

## 외부 의존성 원칙

외부 라이브러리는 필요성이 명확할 때만 도입한다. 전원 관리, 실행 중 앱 목록, 메뉴바 UI는 시스템 API로 구현한다. 전역 단축키 라이브러리는 필요성이 확인된 뒤 도입한다.
