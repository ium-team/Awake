# 구현 계획

## 1. 프로젝트 생성

- macOS App 프로젝트 생성
- 메뉴바 전용 앱 설정
- 앱 이름과 bundle identifier 설정
- 기본 빌드/실행 확인

## 2. 전원 assertion 검증

- `PowerAssertionController` 구현
- assertion 생성/해제 단위 테스트
- `pmset -g assertions`로 수동 검증
- 앱 종료 시 해제 검증

## 3. 세션 상태 모델

- `SessionController` 구현
- idle/active/error 상태 전환
- 중복 시작/중복 종료 처리
- 수동 종료 동작 검증

## 4. 실행 중 앱 목록

- `RunningAppProvider` 구현
- 앱 이름, 아이콘, PID, bundle identifier 수집
- 시스템/백그라운드 앱 필터링
- 선택 화면에 표시

## 5. 보호 대상 선택

- 다중 선택 UI
- 선택 대상 snapshot 생성
- Start 버튼과 세션 시작 연결
- active 상태 메뉴바 반영

## 6. 대상 감시

- `TargetMonitor` 타이머 구현
- PID 생존 확인
- 모든 대상 종료 시 자동 세션 종료
- 체크 간격 설정 반영

## 7. 권한과 실패 상태

- Accessibility 상태 표시
- 알림 권한 처리
- assertion 실패 UI
- 앱 목록 수집 실패 UI

## 8. 단축키와 설정

- 전역 단축키
- 설정 화면
- 최근 대상
- 기본값 저장

## 9. 안정화

- 장시간 실행 테스트
- sleep/wake 후 상태 테스트
- 배터리/전원 연결 상태 테스트
- 덮개 닫힘 동작 문서화
