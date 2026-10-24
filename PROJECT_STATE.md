# Project state for the next agent

Updated: 2026-10-19 (Asia/Karachi)

## Start here

This is a Flutter app for prayer times and tracking, Qibla direction, Quran recitation scheduling, work task scheduling, notifications/alarms, and AdMob ads. The app package is `com.mynamaz.scheduler`. The current version in `pubspec.yaml` is `1.0.3+4`.

The latest commit is `7f06736` (`assets: add 1024x500 Google Play Store feature graphic and app banner`, 2026-10-12). **There is substantial uncommitted work. Preserve and review it before changing the same files.** No code changes were made while preparing this handoff.

## Uncommitted work already present

- `android/app/build.gradle.kts`: pins NDK `28.2.13676358`, excludes two META-INF license resources, and adds release ProGuard rules. New untracked `android/app/proguard-rules.pro` keeps `androidx.work.impl.WorkDatabase_Impl` for runtime lookup.
- `android/app/src/main/AndroidManifest.xml`: removes an explicit Google Play services version metadata entry.
- `android/app/src/main/kotlin/com/mynamaz/scheduler/MainActivity.kt`: catches errors while creating Android alarm notification channels.
- `android/app/src/main/kotlin/com/mynamaz/scheduler/PrayerAlarmReceiver.kt` and `PrayerAlarmService.kt`: catch and log service start/stop and foreground-service errors.
- `lib/core/notifications/notification_service.dart`: catches and logs initialization and channel creation failures individually.
- `lib/core/ads/ad_service.dart`: waits 15 seconds after ad SDK initialization before allowing interstitial ads.
- `lib/main.dart`: adds global Flutter/platform error handlers, an error widget, and guarded initialization/router creation.
- `pubspec.yaml`: bumps version from `1.0.0+1` to `1.0.3+4`.

These edits appear aimed at Android startup and alarm reliability. Their intended behavior has **not** been verified on an Android device in this handoff. In particular, check whether caught failures leave notifications or alarm playback silently unavailable, and whether the router fallback can recover from an initialization failure.

## Verification on 2026-10-19

- `C:\flutter_sdk\bin\flutter.bat test --no-pub`: **passed, 19 tests**.
- `C:\flutter_sdk\bin\flutter.bat analyze`: **19 info-level deprecation notices**, no analyzer errors or warnings. The command exits with code 1 because of those notices. They concern `value` on form fields and `groupValue`/`onChanged` on radios in Quran, task, and settings screens.
- Android build and on-device notification/alarm behavior were **not checked** in this handoff.

## Recommended next work

1. Review the uncommitted changes above against the intended Android crash or alarm issue, then run an Android build (especially release, because the new ProGuard rule is release-specific).
2. Test prayer, Quran, and task alarms on a device or emulator with the app foregrounded, backgrounded, and after a restart; verify the stop action and notification sounds.
3. Resolve any failures found, then decide whether to commit the existing work and version bump. Do not assume the working tree is clean.

## Useful entry points

- App startup and routing: `lib/main.dart`, `lib/core/routing/app_router.dart`.
- Alarm scheduling and Android integration: `lib/core/notifications/notification_service.dart`, `android/app/src/main/kotlin/com/mynamaz/scheduler/`.
- Ads: `lib/core/ads/ad_service.dart`, `lib/shared/widgets/banner_ad_widget.dart`.
- Persistence: `lib/core/database/app_database.dart` (SQLite schema version 2).
- Tests: `test/`.

On this machine, Git may report `dubious ownership` under the sandbox account. For read-only Git commands, pass `-c safe.directory='C:/Users/Supreme Traders/Documents/interview/mynamaz_schudler'` to that invocation.
