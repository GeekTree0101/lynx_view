# Quick Start

## 1. 의존성 추가

```yaml
dependencies:
  flutter:
    sdk: flutter
  lynx_view: ^1.0.0
```

## 2. Android 설정

플러그인이 필요한 Lynx SDK 의존성(`org.lynxsdk.lynx:lynx:4.0.0` 등)을 전이적으로 가져오기 때문에 앱의 `android/app/build.gradle`에 별도 설정은 필요 없습니다.

다만 두 가지는 확인이 필요합니다.

- **minSdkVersion**: 플러그인이 21(Lynx SDK 4.0.0 공식 요구사항)을 강제합니다. 기존 앱의 minSdk가 이보다 낮다면 올려야 합니다.
- **ndkVersion**: Lynx의 네이티브 라이브러리가 `27.0.12077973`을 요구합니다. 앱의 `android/app/build.gradle.kts`에 아래처럼 명시하세요.

```kotlin
android {
    ndkVersion = "27.0.12077973"
    // ...
}
```

커스텀 native module이 필요하면 `Application`에서 앱 시작 시점에 한 번만 등록합니다.

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        LynxViewPlugin.registerNativeModule("YourCustomModule", YourCustomModule::class.java)
    }
}
```

> 등록 호출은 `LynxEnv` 초기화 전/후 아무 때나 해도 안전합니다 — 실제 초기화는 첫 `LynxView`가 생성되는 시점까지 내부적으로 지연(lazy init)되고, 그 전까지 들어온 등록은 큐에 쌓였다가 한 번에 반영됩니다.

## 3. iOS 설정

`ios/Podfile`도 별도 설정이 필요 없습니다 (플러그인이 `Lynx`/`PrimJS` pod를 가져옵니다). 다만 Xcode 빌드 설정에서 **User Script Sandboxing을 NO로 비활성화**해야 합니다 (Lynx SDK 빌드 요구사항).

커스텀 native module이 필요하면 `AppDelegate`에서 등록합니다.

```swift
@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    LynxViewPlugin.registerNativeModule("YourCustomModule", moduleClass: YourCustomModule.self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

> **CocoaPods 전용, 아직 SPM(Swift Package Manager) 미지원.** `lynx_view_ios`가 의존하는 `Lynx`/`PrimJS` pod 자체가 SPM으로 배포되지 않습니다 — Lynx 저장소에 관련 요청 이슈([lynx-family/lynx#162](https://github.com/lynx-family/lynx/issues/162))가 열려 있지만 아직 메인테이너 답변도 없는 상태입니다. Flutter의 SPM 플러그인은 CocoaPods 전용 네이티브 의존성을 섞어 쓸 수 없어서, Lynx가 SPM을 지원하기 전까지는 이 패키지도 지원할 수 없습니다.

## 4. 최소 지원 버전 요약

| 항목 | 값 | 근거 |
|---|---|---|
| Android minSdkVersion | 21 | Lynx SDK 4.0.0 공식 요구사항 (GitHub README) |
| Android NDK | 27.0.12077973 | Lynx 네이티브 라이브러리 빌드 요구사항 |
| iOS deployment target | 12.0 | Lynx 자체는 iOS 10을 지원하지만, Flutter 엔진 자체의 최소 요구사항이 12.0이라 더 높은 값이 실제 바닥값 |

다음 단계: [기본 사용법](./usage.md)
