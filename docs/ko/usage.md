# 기본 사용법

## 설계 철학: 컨트롤러를 앱이 직접 만든다

`LynxView`는 `templateUrl`이나 콜백을 위젯 생성자로 직접 받지 않습니다. 대신 `LynxViewController`를 앱이 먼저 만들어서 위젯에 주입하는 패턴을 씁니다 — `TextEditingController`/`VideoPlayerController`, 최신 `webview_flutter`의 `WebViewController`와 같은 관례입니다.

```dart
class _LynxScreenState extends State<LynxScreen> {
  late final LynxViewController _controller = LynxViewController(
    templateUrl: 'https://your-bucket.s3.amazonaws.com/bundles/home.lynx.bundle',
    initData: const {'userId': '123'},
    onLoadSuccess: () => debugPrint('Lynx bundle loaded'),
    onLoadError: (e) => debugPrint('Lynx load failed: ${e.code} ${e.message}'),
  );

  @override
  Widget build(BuildContext context) => LynxView(controller: _controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

이 패턴을 고른 이유:
- **nullable 컨트롤러가 없음** — `onCreated` 콜백으로 넘겨받는 방식(GoogleMap 스타일)과 달리, `late final`로 non-null이 보장됩니다.
- **네이티브 뷰가 생성되기 전에도 안전** — `reload()`/`sendEvent()`를 위젯이 화면에 붙기도 전에 호출해도, 내부적으로 큐잉했다가 뷰가 준비되면 순서대로 flush합니다.
- **`GlobalKey<State>` 방식은 기각** — State 클래스가 public API로 노출돼야 하고(내부 구현 변경이 API 파괴로 이어짐), `currentState`가 nullable이라 마운트 타이밍에 따라 호출이 조용히 씹힐 수 있습니다.

## 사이징

`LynxView`는 `AndroidView`/`UiKitView` 기반 PlatformView라서 intrinsic size가 없습니다. `SizedBox`, `Expanded`, `AspectRatio` 등으로 감싸서 크기를 명시적으로 줘야 합니다.

```dart
Expanded(
  child: LynxView(controller: _controller),
)
```

## `LynxViewController`의 리소스 정리

`dispose()`는 이 컨트롤러가 소유한 네이티브 `LynxView` 리소스를 **명시적으로** 해제하는 유일한 지점입니다 (`CameraController`/`VideoPlayerController`와 같은 관례). Flutter 위젯이 트리에서 빠졌다고 자동으로 정리되는 게 아니라, 앱이 `State.dispose()`에서 직접 호출해야 합니다.

```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

## `templateUrl`이 가리키는 것

`controller.templateUrl` getter는 **현재 성공적으로 렌더링된** URL을 가리킵니다. `reload()`가 실패하면 이 값은 갱신되지 않고 이전 값 그대로 남습니다 — 화면에 실제로 보이는 내용과 항상 일치하도록 설계했습니다.

다음 단계: [JS ↔ Dart 브릿지](./bridge.md)
