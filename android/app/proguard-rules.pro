##################################
# FFmpegKit Required Rules (All Modules incl. Audio)
##################################
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
-keep class org.ffmpeg.** { *; }
-dontwarn org.ffmpeg.**

##################################
# Flutter Local Notifications Plugin
##################################
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

##################################
# Stripe Push Provisioning (if used)
##################################
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**

##################################
# Gson (generic deserialization)
##################################
-keep class com.google.gson.reflect.TypeToken { *; }
-keepattributes Signature

##################################
# General ProGuard Optimization Settings
##################################
-keepattributes *Annotation*
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter engine and plugin loader
-keep class io.flutter.** { *; }

# Prevent removal of required classes
-dontoptimize
-dontobfuscate
-dontusemixedcaseclassnames
-dontpreverify
-dontskipnonpubliclibraryclasses

-verbose
