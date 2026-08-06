# ProGuard/R8 rules applied to any app that depends on this plugin.
#
# Lynx's own AAR ships keep rules for its @Keep-annotated classes, but it also
# reaches for Gson from LynxEnv.GetNativeEnvDebugDescription() without
# depending on it. R8 treats that dangling reference as an error, so every
# consumer's release build fails with:
#
#   Missing class com.google.gson.Gson
#     (referenced from: java.util.HashMap
#      com.lynx.tasm.LynxEnv.GetNativeEnvDebugDescription())
#
# The call sits on a debug-description path an app never enters, so the classes
# genuinely are not needed at runtime — telling R8 the absence is expected is
# the whole fix. Apps that do pull in Gson themselves are unaffected.
-dontwarn com.google.gson.**

# XElement has two more of these, both on optional feature paths.
#
# `<svg>` can load a remote image, and when it does it goes through Fresco --
# which XElement references but does not depend on, since Lynx expects the host
# app to supply its own image service. An app that wants remote SVG sources
# adds Fresco itself; one that does not never reaches the call.
-dontwarn com.facebook.**
#
# `<markdown>` is excluded outright (see build.gradle), but the umbrella
# artifact's behavior table still names its classes so it can register the tag.
# Registration only stores the name -- the class is not loaded unless a template
# actually uses `<markdown>`, which on Android cannot work regardless.
-dontwarn com.lynx.xelement.markdown.**
