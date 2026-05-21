# 데이터와 저장 구조

## 저장 대상

현재 제품은 `UserDefaults`를 사용한다.

- 체크 간격
- display sleep 방지 여부
- closed-display best-effort 여부
- lid-closed 강제 유지 여부
- lid-closed 세션 중 덮개 닫힘 이벤트에서 화면보호기 실행 여부
- 자동 종료 알림 여부
- 최근 선택 대상 저장 여부
- 최근 선택한 bundle identifier 목록

## 세션 데이터

active 세션은 메모리에 둔다. 앱 재시작 후 이전 세션을 자동 복구하지 않는다.

세션 모델:

```swift
struct AwakeSession {
    let id: UUID
    let startedAt: Date
    let targets: [AwakeTarget]
    let assertionMode: AssertionMode
}
```

대상 모델:

```swift
struct AwakeTarget {
    let kind: TargetKind
    let pid: pid_t
    let bundleIdentifier: String?
    let displayName: String
    let windowID: UInt32?
}
```

## 로그

현재 제품은 파일 로그를 만들지 않는다. 개발 중에는 `os.Logger`를 사용한다. 세션 히스토리가 필요하면 JSON 로그 또는 SQLite를 검토한다.

## 개인정보 원칙

- 윈도우 제목은 민감할 수 있으므로 장기 저장하지 않는다.
- 최근 대상 저장은 bundle identifier 중심으로 한다.
- 터미널 출력, 명령어 내용, 파일 경로를 수집하지 않는다.
