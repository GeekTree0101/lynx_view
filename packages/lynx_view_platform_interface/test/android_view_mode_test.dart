import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers the engine's HCPP support question with [supported], and
  /// accepts whatever view creation follows on either platform-views channel.
  void mockEngine({required bool supported}) {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views_2, (
      MethodCall call,
    ) async {
      if (call.method == 'isSurfaceControlEnabled') return supported;
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      MethodCall call,
    ) async {
      // `create` answers with a texture id for a texture-layer view.
      return call.method == 'create' ? 1 : null;
    });
  }

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views_2, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Widget build(MethodChannelLynxView platform, LynxAndroidViewMode mode) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: platform.buildView(
        creationParams: const <String, dynamic>{'templateUrl': 'https://x/y'},
        onPlatformViewCreated: (_) {},
        androidViewMode: mode,
      ),
    );
  }

  testWidgets('the default mode builds a plain AndroidView', (tester) async {
    mockEngine(supported: true);
    final platform = MethodChannelLynxView();

    await tester.pumpWidget(build(platform, LynxAndroidViewMode.textureLayer));
    await tester.pump();

    expect(find.byType(AndroidView), findsOneWidget);
    expect(find.byType(PlatformViewLink), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('HCPP mode builds an HCPP view where the engine supports it', (
    tester,
  ) async {
    mockEngine(supported: true);
    final platform = MethodChannelLynxView();

    await tester.pumpWidget(
      build(platform, LynxAndroidViewMode.hybridCompositionPlusPlus),
    );
    // Nothing native is built until the engine has answered.
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(PlatformViewLink), findsNothing);

    await tester.pump();

    expect(find.byType(PlatformViewLink), findsOneWidget);
    expect(find.byType(AndroidView), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('HCPP mode falls back where the engine cannot do it', (
    tester,
  ) async {
    mockEngine(supported: false);
    final platform = MethodChannelLynxView();

    await tester.pumpWidget(
      build(platform, LynxAndroidViewMode.hybridCompositionPlusPlus),
    );
    await tester.pump();

    expect(find.byType(AndroidView), findsOneWidget);
    expect(find.byType(PlatformViewLink), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a later view does not wait for the answer again', (
    tester,
  ) async {
    mockEngine(supported: true);
    final platform = MethodChannelLynxView();
    expect(await platform.isAndroidHcppSupported(), isTrue);

    await tester.pumpWidget(
      build(platform, LynxAndroidViewMode.hybridCompositionPlusPlus),
    );

    expect(find.byType(PlatformViewLink), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  test('an engine that does not answer counts as unsupported', () async {
    // No mock handler: the channel call fails the way it does on an engine
    // without the HCPP channel.
    expect(await MethodChannelLynxView().isAndroidHcppSupported(), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  test('HCPP is never supported off Android', () async {
    mockEngine(supported: true);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await MethodChannelLynxView().isAndroidHcppSupported(), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
