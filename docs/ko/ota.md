# OTA / CodePush 연동

이 패키지는 CodePush 같은 OTA(Over-The-Air) 업데이트 시스템을 **직접 만들지 않습니다**. 버전 관리, 롤백, 강제 업데이트, staged rollout, diff 패치 같은 건 전부 스코프 밖입니다 — 그건 서버 인프라의 몫입니다.

대신 이 패키지가 제공하는 건, 외부 OTA/CodePush 클라이언트가 "새 번들 URL이 나왔다"고 알려줬을 때 **그 순간 화면을 갱신할 수 있는 훅**입니다.

```dart
Future<void> onNewBundleAvailable(String newTemplateUrl) async {
  await _controller.reload(newTemplateUrl);
}
```

## 실패 시 동작

`reload()`가 실패하면:

- 기존에 렌더링되던 화면은 **그대로 유지**됩니다 (크래시 없음, 빈 화면 아님)
- `onLoadError` 콜백이 호출됩니다
- **자동 롤백은 하지 않습니다** — 필요하면 앱이 직접 이전 URL로 재시도하거나, 사용자에게 알리는 로직을 짜야 합니다

```dart
late final LynxViewController _controller = LynxViewController(
  templateUrl: initialUrl,
  onLoadError: (error) {
    // 예: 이전 버전으로 롤백을 시도하고 싶다면 여기서 앱이 직접 reload() 재호출
    debugPrint('OTA 번들 로드 실패: ${error.code} ${error.message}');
  },
);
```

## 왜 이렇게 나눴나

- 이 패키지가 "번들을 어떻게 갱신하는가"(HTTP GET)까지는 책임지지만, "언제, 어떤 조건으로 갱신할지 판단하는 로직"(버전 비교, 롤아웃 퍼센티지, 강제 업데이트 여부)까지 떠안으면 패키지가 너무 무거워지고, 앱마다 다른 OTA 전략과 충돌하기 쉽습니다.
- `reload()` + `onLoadError`라는 최소한의 인터페이스만 제공하면, Shorebird/자체 서버/S3 폴링 등 어떤 OTA 전략을 쓰든 그 위에 얹을 수 있습니다.

## 번들 호스팅

v1은 원격 URL 로딩만 지원합니다(로컬 asset 번들 없음). S3 같은 오브젝트 스토리지에 올려두는 것도 물론 가능합니다 — presigned URL, 공개 버킷+CDN, 인증 헤더 중 어떤 방식으로 노출할지는 아직 확정하지 않았고, `templateUrl`/`reload()` 시그니처에 커스텀 헤더 파라미터가 없는 상태입니다. 필요해지면 추가될 수 있는 부분입니다.
