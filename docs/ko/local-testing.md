# 로컬에서 시뮬레이터로 검증하기

`lynx_view`는 원격 URL에서 Lynx 번들을 받아 렌더링합니다. 그래서 로컬에서 눈으로 확인하려면 **번들을 하나 만들어 로컬 서버로 서빙**해야 합니다.

이 문서는 iOS 시뮬레이터 기준입니다. Android는 마지막 절을 참고하세요.

## 1. 테스트용 번들 만들기

Lynx 공식 스캐폴더로 hello-world 템플릿을 만들고 빌드합니다.

```bash
npx -y create-rspeedy hello-lynx --template react-ts
cd hello-lynx
npm install
npm run build
```

`dist/main.lynx.bundle`이 만들어집니다. 이게 앱이 로드할 번들입니다.

## 2. 번들 서빙하기

빌드 결과물 폴더를 정적으로 서빙합니다.

```bash
cd dist
python3 -m http.server 8934 --bind 127.0.0.1
```

잘 떴는지 확인:

```bash
curl -sI http://127.0.0.1:8934/main.lynx.bundle
```

`200 OK`가 나오면 됩니다.

> 번들 JS를 직접 고쳐가며 볼 거라면 `npm run dev`(rspeedy 개발 서버)를 쓰는 게 편합니다. HMR이 됩니다.

## 3. 예제 앱 실행하기

```bash
flutter pub get
cd example/ios && pod install && cd ..
flutter run -d "iPhone 16"
```

> Xcode 빌드 설정에서 **User Script Sandboxing이 NO**여야 합니다 (Lynx SDK 요구사항). 예제 앱은 이미 그렇게 설정돼 있습니다.

## 4. 앱에서 확인할 것

앱이 뜨면 `templateUrl` 입력칸에 2번에서 띄운 주소를 넣고 **Reload**를 누릅니다.

```
http://127.0.0.1:8934/main.lynx.bundle
```

타이핑이 번거로우면 맥에서 시뮬레이터 클립보드로 바로 넣을 수 있습니다.

```bash
echo -n "http://127.0.0.1:8934/main.lynx.bundle" | xcrun simctl pbcopy booted
```

그 다음 아래 네 가지를 확인합니다.

- **렌더링** — 검은 배경에 "Tap the logo and have fun!" 같은 번들 콘텐츠가 그려지고, 로그에 `onLoadSuccess`가 찍힙니다.
- **에러 처리** — 없는 주소로 바꿔 Reload 하면 `onLoadError`가 찍힙니다. 이때 화면은 그대로 남아있고 크래시하지 않아야 합니다.
- **reload()** — 주소를 그대로 두고 Reload를 다시 눌러도 `onLoadSuccess`가 또 찍힙니다. OTA 클라이언트가 호출하는 지점입니다.
- **JS ↔ Dart 브릿지** — `sendEvent("demo") to JS` 버튼을 누르면 `sendEvent -> demo`가 찍힙니다.

**LynxView 아래쪽 위젯(버튼과 로그 목록)이 제대로 보이는지도 같이 봐주세요.** 네이티브 콜백을 메인 스레드가 아닌 곳에서 호출하면 이 부분이 통째로 안 그려집니다. 실제로 그런 버그가 있었습니다.

## 5. 플랫폼별 호스트 주소

`127.0.0.1`은 iOS 시뮬레이터에서만 그대로 통합니다. 나머지는 주소가 다릅니다.

- **iOS 시뮬레이터** — `127.0.0.1` (맥과 localhost를 공유)
- **Android 에뮬레이터** — `10.0.2.2` (에뮬레이터 안에서 호스트를 가리키는 주소)
- **실기기** — 맥의 LAN IP (예: `192.168.0.10`). 같은 와이파이에 있어야 합니다.

또 하나, 로컬 서버는 `https`가 아니라 `http`입니다. 평문 통신이라 OS가 막을 수 있습니다.

- Android는 `usesCleartextTraffic`을 켜야 합니다.
- iOS는 `127.0.0.1`이면 별도 설정 없이 통과합니다. 실기기에서 LAN IP를 쓸 땐 ATS 예외가 필요합니다.

## 6. 정리

서버를 내립니다.

```bash
pkill -f "http.server 8934"
```
