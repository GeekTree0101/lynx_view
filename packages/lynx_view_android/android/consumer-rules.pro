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
