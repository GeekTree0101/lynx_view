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

크기는 «주면 좋은 것»이 아니라 **로드의 전제**입니다. 번들은 `%`·`flex`·`vh`를 레이아웃하는 그 순간의 뷰포트로 풀고, 그 뒤 스스로 다시 풀지 않습니다. 그래서 네이티브 뷰는 Flutter가 실제 크기를 줄 때까지 첫 로드를 미룹니다 — 한 프레임 남짓이고, 그 대신 첫 페인트가 처음부터 맞습니다.

뒤집어 말하면 **크기가 0인 자리에 놓인 `LynxView`는 번들을 받지 않습니다.** 높이 0인 박스에 넣어 두고 미리 데워지길 기대하면 안 됩니다.

## Android 임베딩 방식 — Hybrid Composition++ (선택)

기본값은 지금까지와 같습니다. 네이티브 뷰가 텍스처에 그려지고, Flutter가 그 텍스처를 합성합니다(`AndroidView`).

`LynxView` 하나하나가 Hybrid Composition++(HCPP)를 요청할 수 있습니다. 이때 네이티브 뷰는 Android 뷰 계층에 그대로 남고, 시스템이 Flutter 화면과 맞춰 합성합니다.

```dart
LynxView(
  controller: _controller,
  androidViewMode: LynxAndroidViewMode.hybridCompositionPlusPlus,
)
```

HCPP는 엔진 기능이라 조건이 있습니다.

- Android 14(API 34) 이상, Impeller + Vulkan.
- Flutter 3.32 이상.
- `AndroidManifest.xml`의 `<application>` 안에 opt-in. 키 이름이 중간에 바뀌었습니다. 엔진은 모르는 키를 무시하므로 둘 다 적어도 됩니다.

```xml
<!-- Flutter 3.32 ~ 3.41 -->
<meta-data
    android:name="io.flutter.embedding.android.EnableSurfaceControl"
    android:value="true" />
<!-- 그 이후 -->
<meta-data
    android:name="io.flutter.embedding.android.EnableHcpp"
    android:value="true" />
```

조건이 하나라도 빠진 기기에서는 같은 `LynxView`가 알아서 기본 방식으로 뜹니다. 앱 코드에서 분기할 필요가 없습니다. 지금 어느 쪽인지는 `await LynxView.isAndroidHcppSupported()`로 확인합니다.

켜기 전에 알아야 할 두 가지:

- **매니페스트 스위치는 엔진 전체에 걸립니다.** HCPP가 켜진 기기에서는 Flutter가 기존 Hybrid Composition 뷰(`PlatformViewsService.initExpensiveAndroidView`, 또는 그쪽으로 폴백하는 `initSurfaceAndroidView`) 생성을 거부하고 예외를 던집니다. 앱의 다른 플랫폼 뷰(광고·지도·웹뷰)를 먼저 확인하세요. 일반 `AndroidView`는 그대로 됩니다.
- **바뀌는 것은 렌더링이지 터치가 아닙니다.** 두 방식 모두 Flutter가 터치를 먼저 받고 제스처 아레나가 번들로 넘길지 정합니다. `gestureRecognizers` 동작은 같습니다.

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

## 폰트

Lynx는 폰트를 스스로 가져오지 않습니다. 템플릿이 `font-family`에 이름을 적어도 아무도 등록해 주지 않았으면 **조용히 시스템 폰트로 그려집니다**. 앱이 이미 갖고 있는 파일을 그대로 넘기세요.

```dart
LynxViewController(
  templateUrl: '...',
  fonts: const [
    LynxFontAsset(family: 'Pretendard-Regular', assetPath: 'assets/fonts/Pretendard-Regular.otf'),
    LynxFontAsset(family: 'Pretendard-Bold',    assetPath: 'assets/fonts/Pretendard-Bold.otf'),
  ],
);
```

`assetPath`는 앱 `pubspec.yaml`에 적힌 그대로의 Flutter asset 키입니다. `fonts:` 아래 선언한 파일도 asset 번들에 함께 들어가므로, Flutter 화면이 이미 쓰는 폰트라면 사본을 따로 둘 필요가 없습니다.

**family 하나 = 굵기 하나입니다.** Lynx는 `font-family`를 이름으로만 찾습니다 — 한 이름에 등록된 여러 굵기 중에서 고르는 경로가 없고, 안드로이드는 CSS weight 500 이상이 전부 "bold" 한 칸으로 접힙니다. 굵기마다 family를 따로 주고 `font-weight`가 아니라 `font-family`로 고르세요.

등록은 뷰가 만들어지는 동안 네이티브에서 일어나므로 **첫 페인트부터** 폰트가 맞습니다. 프로세스당 한 번만 수행되며, 읽지 못한 폰트는 로그만 남기고 건너뜁니다 — 화면은 시스템 폰트로 계속 그려집니다.

## 원격 리소스 — `<svg src>`, URL 로 적은 폰트

`<image>` 는 이미지 서비스가 알아서 받아옵니다. 그 밖에 템플릿이 URL 로 적는 것 — `<svg src="https://…">`, 폰트 파일, Lottie 파일 — 은 Lynx 가 기본 로더를 주지 않습니다. 로더가 없으면 XElement 의 `<svg>` 는 **아무것도 그리지 않고**, Android 는 로그 한 줄(`getGenericResourceFetcher is null`)만 남기고 iOS 는 그마저 없습니다. 패키지가 로더를 하나 꽂아 두므로 아래가 그대로 됩니다.

```jsx
<svg src="https://cdn.example.com/icons/locomotive.svg" style={{ width: '36px', height: '36px' }} />
```

기본 로더는 헤더 없는 `GET` 이고 캐시는 플랫폼 기본값을 따릅니다. 공개 객체, CDN 경로, 서명 URL 이면 이걸로 충분합니다. 버킷이 인증 헤더를 요구하거나 앱에 공유할 캐시가 있으면, 첫 뷰가 만들어지기 전에 직접 만든 것을 넘기세요.

```swift
// AppDelegate.swift
LynxViewPlugin.setResourceFetcher(MyResourceFetcher())   // LynxGenericResourceFetcher. nil 이면 기본으로 복귀
```

```kotlin
// Application.onCreate
LynxViewPlugin.setResourceFetcher(MyResourceFetcher())   // LynxGenericResourceFetcher. null 이면 기본으로 복귀
```

파일이 어떻게 오든 SVG 렌더러가 안 하는 일 둘은 같습니다. `currentColor` 를 풀지 않으니 색은 파일에 리터럴로 적고, 파일 자체의 `width`/`height` 는 무시되니 크기는 엘리먼트 `style` 로 정합니다.

다음 단계: [JS ↔ Dart 브릿지](./bridge.md)
