# JS ↔ Dart 브릿지

Lynx 자체 아키텍처상 두 방향의 통신 난이도가 다릅니다.

- **Dart → JS**: Lynx가 `GlobalEventEmitter`라는 범용 pub/sub을 기본 제공해서, 커스텀 모듈 없이 바로 됩니다.
- **JS → Dart**: Lynx의 공식 방식은 "타입드 NativeModule 클래스를 앱이 네이티브로 정의"하는 것뿐입니다. 그래서 네이티브 코드 없이 쓰고 싶다면, 이 패키지가 미리 만들어둔 범용 모듈(`FlutterBridge`)을 쓰는 수밖에 없습니다.

이 패키지는 두 계층(Tier)을 함께 제공합니다. 대부분은 Tier 1으로 충분합니다.

## Tier 1 — `FlutterBridge` 기본 브릿지 (네이티브 코드 불필요)

```dart
_controller.addJavaScriptChannel(
  'MyChannel',
  onMessageReceived: (LynxMessage message) {
    debugPrint('from JS: ${message.data}');
  },
);

_controller.sendEvent('MyChannel', {'greeting': 'hello from Flutter'});

// 더 이상 안 받아도 되면 해제
_controller.removeJavaScriptChannel('MyChannel');
```

번들 JS 쪽:

```js
// JS → Dart: 패키지가 내장 제공하는 FlutterBridge 모듈 사용
NativeModules.FlutterBridge.postMessage('MyChannel', JSON.stringify({ hello: 'from lynx' }));

// Dart → JS: GlobalEventEmitter 구독
lynx.getJSModule('GlobalEventEmitter').addListener('MyChannel', (data) => {
  console.log('from Flutter:', data);
});
```

`addJavaScriptChannel`/`removeJavaScriptChannel`은 Dart 쪽 콜백 등록/해제만 하기 때문에, 네이티브 `LynxView`가 아직 생성되기 전에 호출해도 즉시 반영됩니다 (큐잉 대상이 아님). 반면 `sendEvent`는 실제로 네이티브 호출이 필요해서, 뷰가 준비되기 전에 호출하면 내부 큐에 쌓였다가 준비되는 즉시 실행됩니다.

## Tier 2 — 커스텀 Native Module (타입드/고성능이 필요할 때)

`FlutterBridge`로는 문자열 기반 메시지만 오가기 때문에, 타입 안정성이나 무거운 연산이 필요하면 앱이 직접 네이티브 모듈을 만들어 등록합니다.

**중요**: 앱이 만드는 모듈은 `LynxEnv`/`LynxConfig` 레벨(엔진 전역)에 등록합니다. `LynxView`나 `LynxViewController`는 이 과정에 관여하지 않습니다 — 그래서 등록은 Dart API가 아니라 **앱의 기존 네이티브 코드에서, 앱 시작 시점에 한 번만** 이뤄집니다. 자세한 내용은 [Quick Start](./quick-start.md)를 참고하세요.

> 뷰 단위 등록도 Lynx에 있긴 합니다(Android `LynxViewBuilder.registerModule`). 이 패키지의 내장 `FlutterBridge`는 "어느 Flutter 뷰로 답을 보낼지"를 알아야 해서 그쪽을 씁니다. 앱 모듈은 그럴 이유가 없으니 전역 등록이 맞습니다.

등록된 모듈은 JS에서 그대로 호출합니다.

```js
NativeModules.YourCustomModule.track('screen_view', { screen: 'home' });
```

### 왜 등록 호출을 자동화(codegen/런타임 스캔)하지 않았나

Android는 annotation processor, iOS는 Objective-C 런타임 스캔으로 등록 호출 자체를 앱이 안 써도 되게 만드는 것도 검토했습니다. 하지만 v1에서는:

- Android는 별도 컴파일 타임 빌드 도구(패키지 하나 추가)가 필요해지고
- 잘못 세팅되면 "왜 모듈이 인식 안 되지" 디버깅이 명시적 호출보다 훨씬 어려워집니다

그래서 **명시적 등록 호출을 유지**하기로 했습니다. 보일러플레이트 한 줄과 맞바꾼 선택입니다.

다음 단계: [OTA / CodePush 연동](./ota.md)
