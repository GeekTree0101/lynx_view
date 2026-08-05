# 메모리

`LynxView`는 가벼운 위젯이 아닙니다. 하나마다 엔진, JS 런타임, 요소 트리, 자체 이미지 캐시를 갖고,
그게 전부 **앱 프로세스 안**에 있습니다. `WKWebView`가 웹 콘텐츠를 별도 프로세스에 두고 OS가 그쪽으로
따로 청구하는 것과 다릅니다.

여기서 두 가지가 따라오는데, 첫 번째는 패키지가 알아서 처리합니다.

## 메모리 압박은 자동으로 전달됩니다

Flutter는 이미 OS의 메모리 경고를 `didHaveMemoryPressure()`로 배달하고(iOS
`applicationDidReceiveMemoryWarning`, Android `onTrimMemory`), Lynx는 `LynxEnv.trimMemory()`를
갖고 있습니다. 이 패키지가 그 둘을 잇습니다 — 이전에는 연결이 없어서, 살아 있는 `LynxView`가 OS에
죽는 순간까지 캐시를 붙들고 있었습니다.

**따로 설정할 게 없습니다.** 릴레이는 `LynxView`가 화면에 있는 동안만 설치되므로, Lynx를 안 쓰는
화면에서는 비용이 0입니다.

직접 부르고 싶다면:

```dart
await LynxMemory.trim(LynxMemoryPressureLevel.critical);
```

| 레벨 | 의미 |
| --- | --- |
| `moderate` | 다시 만들기 싼 버퍼만 놓는다 |
| `critical` | 놓을 수 있는 건 다 놓는다 — 대안은 OS에 죽는 것 |

## 어디로 갔는지 물어볼 수 있습니다

RSS로 추정하지 마세요. RSS는 매핑된 공유 라이브러리까지 세기 때문에 **OS가 실제로 앱에 물리는
footprint보다 훨씬 크게 나옵니다** (실측에서 2배 차이가 났습니다).

```dart
final usage = await LynxMemory.usage();

usage.appBytes;                     // 앱의 physical footprint — OS가 보는 값
usage.totalBytes;                   // 그중 Lynx 몫
usage.ratioToApp;                   // 둘의 비율

usage.elementBytes;                 // 요소 트리
usage.elementNodeCount;             // 요소 노드 수
usage.viewBytes;                    // Lynx가 만든 플랫폼 뷰
usage.mainThreadRuntimeBytes;       // 메인 스레드 JS (PrimJS)
usage.backgroundThreadRuntimeBytes; // 백그라운드 JS — iOS는 JavaScriptCore

for (final i in usage.instances) {  // 살아 있는 뷰별 상세
  print('${i.instanceId} ${i.url} ${i.totalBytes}');
}
```

수집은 비동기이고 기본 2000ms 타임아웃이 걸립니다. 시간 안에 못 받으면 **부분 결과라도 돌려주고**
`usage.timedOut`이 `true`가 됩니다. `completedInstanceCount`가 `expectedInstanceCount`보다 작으면
그만큼 빠진 값입니다.

`timeoutMs`로 조정할 수 있습니다.

```dart
final usage = await LynxMemory.usage(timeoutMs: 500);
```

## 개수보다 해제가 중요합니다

몇 개 띄우는 건 최신 기기 예산의 한 자릿수 % 수준이라 그것만으로 앱이 죽지 않습니다. **상한이 없는
건 해제가 안 되는 경우입니다** — 세션이 길어질수록 무한히 자랍니다.

- `State.dispose()`에서 `controller.dispose()`를 반드시 부르세요
- 화면 밖 뷰를 살려두기보다, 다시 만들기 싼 것은 버리는 편이 낫습니다
- 다만 **재진입 시 번들을 다시 받습니다** — 이 패키지에는 번들 캐시가 없습니다. 서버 데이터·스크롤
  위치 같은 상태도 같이 날아가므로, 상태가 무거운 화면은 살려두는 쪽이 나을 수 있습니다

## 참고: 안드로이드 릴리스 빌드

Lynx가 Gson을 참조하는데 그 의존성을 들고 오지 않아서, R8이 도는 릴리스 빌드가
`Missing class com.google.gson.Gson`으로 실패합니다. 이 패키지가 consumer ProGuard 규칙을 실어
보내므로 **앱에서 따로 할 일은 없습니다.** 1.2.0 이전 버전을 쓴다면 앱의 `proguard-rules.pro`에
`-dontwarn com.google.gson.**`을 넣어야 합니다.
