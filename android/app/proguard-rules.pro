# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Core (Split Install / Deferred Components) — Flutter
# referencia essas classes opcionalmente. Não usamos deferred
# components neste app, então avisamos o R8 para ignorá-las.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# LiveKit
-keep class livekit.** { *; }
-keep class org.livekit.** { *; }

# WebRTC
-keep class org.webrtc.** { *; }
