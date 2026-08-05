import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lynx_view/lynx_view.dart';
import 'package:lynx_view/src/lynx_memory.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

class _RecordingPlatform extends LynxViewPlatform {
  final List<LynxMemoryPressureLevel> trims = <LynxMemoryPressureLevel>[];

  @override
  Widget buildView({
    required Map<String, dynamic> creationParams,
    required LynxPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  }) {
    // Hand the controller a viewId the way a real platform view would, so the
    // widget under test exercises the same attach path.
    WidgetsBinding.instance.addPostFrameCallback((_) => onPlatformViewCreated(1));
    return const SizedBox.expand();
  }

  @override
  void setEventHandler(int viewId, LynxViewEventHandler handler) {}

  @override
  Future<void> dispose(int viewId) async {}

  @override
  Future<void> trimMemory(LynxMemoryPressureLevel level) async {
    trims.add(level);
  }
}

void main() {
  late _RecordingPlatform platform;

  setUp(() {
    platform = _RecordingPlatform();
    LynxViewPlatform.instance = platform;
  });

  test('LynxMemory.trim forwards the level to the platform', () async {
    await LynxMemory.trim(LynxMemoryPressureLevel.moderate);
    await LynxMemory.trim(LynxMemoryPressureLevel.critical);

    expect(platform.trims, <LynxMemoryPressureLevel>[
      LynxMemoryPressureLevel.moderate,
      LynxMemoryPressureLevel.critical,
    ]);
  });

  test('pressure levels use Lynx\'s own numbering', () {
    expect(LynxMemoryPressureLevel.moderate.value, 1);
    expect(LynxMemoryPressureLevel.critical.value, 2);
  });

  testWidgets('the relay is installed only while a LynxView is mounted',
      (WidgetTester tester) async {
    expect(LynxMemoryPressureRelay.isInstalledForTesting, isFalse);

    final LynxViewController controller =
        LynxViewController(templateUrl: 'https://a.example/1.bundle');
    addTearDown(controller.dispose);

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LynxView(controller: controller),
    ));

    expect(LynxMemoryPressureRelay.isInstalledForTesting, isTrue);
    expect(LynxMemoryPressureRelay.refCountForTesting, 1);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(LynxMemoryPressureRelay.isInstalledForTesting, isFalse,
        reason: 'an app with no Lynx view on screen should pay nothing');
    expect(LynxMemoryPressureRelay.refCountForTesting, 0);
  });

  testWidgets('two views share one relay and the last one out removes it',
      (WidgetTester tester) async {
    final LynxViewController a =
        LynxViewController(templateUrl: 'https://a.example/1.bundle');
    final LynxViewController b =
        LynxViewController(templateUrl: 'https://a.example/2.bundle');
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    Widget wrap(List<Widget> children) => Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: children),
        );

    await tester.pumpWidget(wrap(<Widget>[
      LynxView(controller: a),
      LynxView(controller: b),
    ]));
    expect(LynxMemoryPressureRelay.refCountForTesting, 2);
    expect(LynxMemoryPressureRelay.isInstalledForTesting, isTrue);

    await tester.pumpWidget(wrap(<Widget>[LynxView(controller: a)]));
    expect(LynxMemoryPressureRelay.refCountForTesting, 1);
    expect(LynxMemoryPressureRelay.isInstalledForTesting, isTrue,
        reason: 'one view is still on screen');

    await tester.pumpWidget(wrap(<Widget>[]));
    expect(LynxMemoryPressureRelay.refCountForTesting, 0);
    expect(LynxMemoryPressureRelay.isInstalledForTesting, isFalse);
  });

  testWidgets('a platform memory warning asks Lynx to release everything',
      (WidgetTester tester) async {
    final LynxViewController controller =
        LynxViewController(templateUrl: 'https://a.example/1.bundle');
    addTearDown(controller.dispose);

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LynxView(controller: controller),
    ));
    platform.trims.clear();

    // What iOS's applicationDidReceiveMemoryWarning and Android's
    // onTrimMemory arrive as.
    tester.binding.handleMemoryPressure();
    await tester.pump();

    expect(platform.trims, <LynxMemoryPressureLevel>[
      LynxMemoryPressureLevel.critical,
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    platform.trims.clear();

    // Nothing left to trim once the view is gone.
    tester.binding.handleMemoryPressure();
    await tester.pump();

    expect(platform.trims, isEmpty);
  });
}
