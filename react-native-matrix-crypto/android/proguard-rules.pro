# Matrix Crypto Bridge
-keep class com.matrix.crypto.** { *; }
-keepclassmembers class com.matrix.crypto.** { *; }

# React Native
-keep class com.facebook.react.** { *; }
-keepclassmembers class com.facebook.react.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.** { *; }

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
