# V1 PRODUCTION HARDENING

# Keep the E2E Cryptography library
-keep class com.google.crypto.tink.** { *; }
-keep class org.cryptography.** { *; }

# Keep Socket.IO classes from being scrambled
-keep class io.socket.** { *; }
-keep class okhttp3.** { *; }

# Prevent Flutter attributes from being removed
-keepattributes Signature,Exceptions,*Annotation*,InnerClasses
