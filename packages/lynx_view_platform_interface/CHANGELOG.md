## 1.3.0

* Version aligned across the federated packages so they move in lockstep; no
  functional change in this one.

## 1.2.0

* Added `LynxViewPlatform.trimMemory` and `LynxViewPlatform.queryMemoryUsage`,
  carried over a new process-wide plugin channel (these are not per-view calls).
* Added `LynxMemoryPressureLevel`, `LynxMemoryUsage` and `LynxInstanceMemory`.
* Both new methods have throwing defaults, so existing platform implementations
  keep compiling.

## 1.0.0

* Initial release: `LynxViewPlatform` interface and the shared `MethodChannelLynxView` implementation used by `lynx_view_android`/`lynx_view_ios`.
