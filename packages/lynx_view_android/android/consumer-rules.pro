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
# `<svg>` can load a remote image, and when it does it goes through Fresco.
# Since 1.5.0 the plugin ships Fresco itself (the image service is built on
# it), so the classes are present at runtime; the -dontwarn stays because
# XElement still references Fresco entry points that the shipped Fresco
# modules do not all declare, and Fresco's own consumer rules do not cover
# XElement's reflective reach.
-dontwarn com.facebook.**
#
# `<markdown>` is excluded outright (see build.gradle), but the umbrella
# artifact's behavior table still names its classes so it can register the tag.
# Registration only stores the name -- the class is not loaded unless a template
# actually uses `<markdown>`, which on Android cannot work regardless.
-dontwarn com.lynx.xelement.markdown.**
