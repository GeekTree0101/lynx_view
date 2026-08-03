import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lynx_view/lynx_view.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

class _FakeLynxViewPlatform extends LynxViewPlatform {
  int nextViewId = 1;
  final List<String> calls = <String>[];
  final Map<int, LynxViewEventHandler> handlers = <int, LynxViewEventHandler>{};

  @override
  Widget buildView({
    required Map<String, dynamic> creationParams,
    required LynxPlatformViewCreatedCallback onPlatformViewCreated,
  }) {
    return const SizedBox.shrink();
  }

  @override
  void setEventHandler(int viewId, LynxViewEventHandler handler) {
    handlers[viewId] = handler;
  }

  @override
  Future<void> reload(
    int viewId, {
    required String templateUrl,
    Map<String, dynamic>? initData,
  }) async {
    calls.add('reload:$viewId:$templateUrl');
  }

  @override
  Future<void> sendEvent(
    int viewId, {
    required String name,
    required Map<String, dynamic> args,
  }) async {
    calls.add('sendEvent:$viewId:$name');
  }

  @override
  Future<void> dispose(int viewId) async {
    calls.add('dispose:$viewId');
  }
}

void main() {
  late _FakeLynxViewPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeLynxViewPlatform();
    LynxViewPlatform.instance = fakePlatform;
  });

  test('reload/sendEvent queue until attach() and flush in order', () async {
    final controller = LynxViewController(templateUrl: 'https://a.example/1.bundle');

    final Future<void> reloadFuture =
        controller.reload('https://a.example/2.bundle');
    final Future<void> sendEventFuture =
        controller.sendEvent('chan', <String, dynamic>{'x': 1});

    expect(fakePlatform.calls, isEmpty);

    controller.attach(7);
    await reloadFuture;
    await sendEventFuture;

    expect(fakePlatform.calls, <String>[
      'reload:7:https://a.example/2.bundle',
      'sendEvent:7:chan',
    ]);
    expect(controller.templateUrl, 'https://a.example/2.bundle');
  });

  test('calls made after attach() run immediately', () async {
    final controller = LynxViewController(templateUrl: 'https://a.example/1.bundle');
    controller.attach(3);

    await controller.sendEvent('chan', <String, dynamic>{});

    expect(fakePlatform.calls, <String>['sendEvent:3:chan']);
  });

  test('addJavaScriptChannel routes onMessage by channel name', () {
    final controller = LynxViewController(templateUrl: 'https://a.example/1.bundle');
    controller.attach(5);

    final List<LynxMessage> received = <LynxMessage>[];
    controller.addJavaScriptChannel(
      'chan',
      onMessageReceived: received.add,
    );

    fakePlatform.handlers[5]!.onMessage('chan', const LynxMessage(data: 'hi'));
    fakePlatform.handlers[5]!.onMessage('other', const LynxMessage(data: 'ignored'));

    expect(received, hasLength(1));
    expect(received.single.data, 'hi');

    controller.removeJavaScriptChannel('chan');
    fakePlatform.handlers[5]!.onMessage('chan', const LynxMessage(data: 'again'));
    expect(received, hasLength(1));
  });

  test('onLoadSuccess/onLoadError callbacks fire via the event handler', () {
    LynxLoadError? capturedError;
    var successCount = 0;

    final controller = LynxViewController(
      templateUrl: 'https://a.example/1.bundle',
      onLoadSuccess: () => successCount++,
      onLoadError: (e) => capturedError = e,
    );
    controller.attach(9);

    fakePlatform.handlers[9]!.onLoadSuccess();
    fakePlatform.handlers[9]!
        .onLoadError(const LynxLoadError(code: 'x', message: 'y'));

    expect(successCount, 1);
    expect(capturedError?.code, 'x');
  });

  test('dispose() calls the platform once and is idempotent', () async {
    final controller = LynxViewController(templateUrl: 'https://a.example/1.bundle');
    controller.attach(11);

    await controller.dispose();
    await controller.dispose();

    expect(fakePlatform.calls, <String>['dispose:11']);
  });

  test('dispose() before attach() does not call the platform', () async {
    final controller = LynxViewController(templateUrl: 'https://a.example/1.bundle');
    await controller.dispose();
    expect(fakePlatform.calls, isEmpty);
  });

  test('methods throw after dispose()', () async {
    final controller = LynxViewController(templateUrl: 'https://a.example/1.bundle');
    await controller.dispose();
    expect(() => controller.reload('https://a.example/2.bundle'), throwsStateError);
  });
}
