# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

-keep public class com.nvidia.shield.smbauth.nas.SmbResult { *; }
-keep public class com.nvidia.shield.smbauth.nas.SmbReceiver { *; }
-keep public class com.nvidia.shield.smbauth.nas.SmbService { *; }
-keep public class com.android.tv.settings.** { *; }

-keep public class com.nvidia.shield.smbauth.nas.SmbClient {
   public static com.nvidia.shield.smbauth.nas.SmbResult getShares(String, String, String, String, List<String>);
   native <methods>;
}

-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

-keepnames public class com.nvidia.shield.smbauth.nas.*
-keepnames public class com.nvidia.shield.smbauth.settings.*
