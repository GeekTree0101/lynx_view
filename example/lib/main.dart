import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lynx_view/lynx_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lynx_view example',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const LynxDemoPage(),
    );
  }
}

/// Demonstrates the three things this package is meant to make easy:
/// 1. Rendering a remote Lynx bundle in a PlatformView.
/// 2. Reloading it at runtime (what an OTA/CodePush-style client would do).
/// 3. Talking to the bundle's JS via the built-in `FlutterBridge` channel —
///    no app-authored native module required.
class LynxDemoPage extends StatefulWidget {
  const LynxDemoPage({super.key});

  @override
  State<LynxDemoPage> createState() => _LynxDemoPageState();
}

class _LynxDemoPageState extends State<LynxDemoPage> {
  static const _defaultTemplateUrl =
      'https://your-bucket.s3.amazonaws.com/bundles/home.lynx.bundle';

  final _urlController = TextEditingController(text: _defaultTemplateUrl);
  final _log = <String>[];

  late final LynxViewController _controller = LynxViewController(
    templateUrl: _defaultTemplateUrl,
    onLoadSuccess: () => _appendLog('onLoadSuccess'),
    onLoadError: (error) => _appendLog('onLoadError: ${error.code} ${error.message}'),
  );

  @override
  void initState() {
    super.initState();
    _controller.addJavaScriptChannel(
      'demo',
      onMessageReceived: (message) => _appendLog('from JS: ${message.data}'),
    );
  }

  void _appendLog(String entry) {
    if (!mounted) return;
    setState(() => _log.insert(0, entry));
  }

  Future<void> _reload() async {
    try {
      await _controller.reload(_urlController.text);
    } catch (e) {
      _appendLog('reload() failed: $e');
    }
  }

  Future<void> _sendEventToJs() async {
    try {
      await _controller.sendEvent('demo', {'greeting': 'hello from Flutter'});
      _appendLog('sendEvent -> demo');
    } catch (e) {
      _appendLog('sendEvent() failed: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('lynx_view example')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(labelText: 'templateUrl'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _reload, child: const Text('Reload')),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: ColoredBox(
              color: Colors.black12,
              child: LynxView(
                controller: _controller,
                // Without this the template's own scroll-view never receives
                // drags — Flutter keeps them.
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: _sendEventToJs,
              child: const Text('sendEvent("demo") to JS'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: false,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _log.length,
              itemBuilder: (context, index) => Text(_log[index]),
            ),
          ),
        ],
      ),
    );
  }
}
