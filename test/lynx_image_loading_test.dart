import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lynx_view/lynx_view.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.geektree0101.lynx_view/plugin');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    LynxViewPlatform.instance = MethodChannelLynxView();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setRequestCancellation goes over the plugin channel with the flag',
      () async {
    await LynxImageLoading.setRequestCancellation(true);
    await LynxImageLoading.setRequestCancellation(false);

    expect(calls.map((MethodCall c) => c.method), <String>[
      'setImageRequestCancellation',
      'setImageRequestCancellation',
    ]);
    expect(calls.map((MethodCall c) => c.arguments), <Object?>[
      <String, dynamic>{'enabled': true},
      <String, dynamic>{'enabled': false},
    ]);
  });
}
