# R8 코드 축소 규칙.
#
# 릴리스 빌드에서 앱이 시작하자마자 죽었다 (2026-08-19, S23 울트라에서 확인).
# 원인은 R8이 androidx.work가 쓰는 Room 생성 클래스(WorkDatabase_Impl)를
# 지워버린 것. Room은 그 클래스를 **리플렉션으로** 찾기 때문에 R8에게는
# 죽은 코드로 보인다.
#
#   java.lang.RuntimeException: Failed to create an instance of
#   androidx.work.impl.WorkDatabase
#     at androidx.startup.InitializationProvider.onCreate
#
# WorkManager는 우리가 직접 쓰지 않고 google_mobile_ads가 끌고 들어온다.
# photo_tidy에서는 ML Kit이 같은 사고를 냈다 — 네이티브 의존성을 추가할
# 때마다 릴리스 APK를 실기기에서 실행해 볼 것.

# --- Room ---------------------------------------------------------------
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
-keep class androidx.room.RoomDatabase { *; }
-dontwarn androidx.room.paging.**

# --- WorkManager --------------------------------------------------------
-keep class androidx.work.impl.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

# App Startup가 리플렉션으로 초기화 클래스를 만든다.
-keep class * extends androidx.startup.Initializer { *; }
-keep class androidx.startup.** { *; }

# --- Google Mobile Ads ---------------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# --- Flutter ------------------------------------------------------------
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
