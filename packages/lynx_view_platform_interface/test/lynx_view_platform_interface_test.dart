import 'package:flutter_test/flutter_test.dart';
import 'package:lynx_view_platform_interface/lynx_view_platform_interface.dart';

void main() {
  test('LynxViewPlatform.instance defaults to MethodChannelLynxView', () {
    expect(LynxViewPlatform.instance, isInstanceOf<MethodChannelLynxView>());
  });

  test('LynxLoadError exposes code and message', () {
    const error = LynxLoadError(code: 'network_error', message: 'timed out');
    expect(error.code, 'network_error');
    expect(error.message, 'timed out');
  });

  test('LynxMessage exposes the decoded payload', () {
    const message = LynxMessage(data: {'foo': 'bar'});
    expect(message.data, {'foo': 'bar'});
  });
}
