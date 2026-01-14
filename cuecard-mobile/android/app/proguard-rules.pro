# Firebase
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Firebase Crashlytics
-keep public class * extends java.lang.Exception

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep serializable classes
-keep,includedescriptorclasses class com.thisisnsh.cuecard.android.models.**$$serializer { *; }
-keepclassmembers class com.thisisnsh.cuecard.android.models.** {
    *** Companion;
}
-keepclasseswithmembers class com.thisisnsh.cuecard.android.models.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Credential Manager
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** {
  *;
}
