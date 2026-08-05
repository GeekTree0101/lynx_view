# lynx_view 한국어 문서

[LynxJS](https://lynxjs.org)의 네이티브 `LynxView`(Android `View` / iOS `UIView` 상속)를 Flutter의 `PlatformView`로 감싸서, 기존 Flutter 앱에 Lynx 템플릿을 임베드할 수 있게 해주는 패키지입니다.

pub.dev 페이지에 노출되는 [루트 README.md](../../README.md)는 영어로 유지하고, 이 폴더에 더 자세한 한국어 설명을 둡니다.

## 문서 목차

- [Quick Start](./quick-start.md) — 의존성 추가부터 Android/iOS 초기 설정까지
- [기본 사용법](./usage.md) — `LynxView` 위젯과 `LynxViewController`
- [JS ↔ Dart 브릿지](./bridge.md) — 네이티브 코드 없이 쓰는 기본 브릿지(Tier 1)와 커스텀 네이티브 모듈(Tier 2)
- [OTA / CodePush 연동](./ota.md) — `reload()`로 런타임에 번들 교체하기
- [메모리](./memory.md) — 자동 압박 대응, `LynxMemory.usage()`로 사용량 확인, 해제가 왜 개수보다 중요한지
- [로컬 검증 가이드](./local-testing.md) — 테스트용 번들을 만들어 시뮬레이터에서 직접 확인하기

## 이 패키지가 하지 않는 것

- Lynx JS ↔ Flutter 사이의 특정 비즈니스 로직용 NativeModule을 미리 만들어두지 않습니다 (등록 메커니즘만 제공)
- 원격 번들에 대한 로컬 캐싱/오프라인 지원이 없습니다 (매번 네트워크에서 로드) — [메모리 문서](./memory.md)의 "개수보다 해제가 중요합니다" 절과 함께 읽으세요
- Web / Desktop / HarmonyOS는 지원 대상이 아닙니다 (Android/iOS만)
- CodePush류 OTA 업데이트 서버·버전관리·롤아웃 인프라를 자체 구축하지 않습니다 — 외부 OTA 클라이언트가 붙을 수 있는 훅(`reload()`, `onLoadError`)만 제공합니다
