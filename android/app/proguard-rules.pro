# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Google Sign-In ────────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.api.client.** { *; }

# ── Google APIs（googleapis 套件） ────────────────────────────────────────────
-keep class com.google.api.services.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.api.client.**
-dontwarn com.google.api.services.**

# ── SQLite / sqflite ──────────────────────────────────────────────────────────
-keep class net.sqlcipher.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn net.sqlcipher.**

# ── Google Maps ───────────────────────────────────────────────────────────────
-keep class com.google.maps.** { *; }
-keep class com.google.android.libraries.maps.** { *; }
-dontwarn com.google.maps.**

# ── Kotlin Reflection（Riverpod / Freezed 在 release 中可能用到） ─────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# ── JSON 序列化（json_serializable 產生的 fromJson/toJson） ───────────────────
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── OkHttp / http 套件 ────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**

# ── 一般安全規則 ──────────────────────────────────────────────────────────────
# 保留所有 Parcelable 實作（Android 序列化機制）
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
# 保留所有 Serializable 類別的欄位
-keepclassmembers class * implements java.io.Serializable {
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
