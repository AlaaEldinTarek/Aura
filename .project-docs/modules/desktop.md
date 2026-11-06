# Windows desktop
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Scaling system: desktop-scaling.md.

## Build
```powershell
dart run msix:create          # builds windows + wraps into MSIX
Add-AppxPackage -Path "build\windows\x64\runner\Release\aura_app.msix" -ForceApplicationShutdown
```

## MSIX versioning
- Every Windows build that replaces an installed package needs a strictly higher `msix_version` in `pubspec.yaml`
  (format `major.minor.patch.build`). Increment the last segment for each reinstall during development.
- Series `1.0.3.x`. Old CLAUDE.md said "last used 1.0.3.64"; `pubspec.yaml` has `1.0.3.114` (VERIFIED 2026-11-06).

## Not yet documented
- `lib/core/services/desktop_notification_service.dart`, `windows_startup_service.dart` (startup toggle), sleep-aware
  timers — added in commit 75d38b9. UNKNOWN details, Step 2.
