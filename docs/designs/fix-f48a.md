# Fix F48a — Qibla instruction text: wrong direction + 0/360 wrap

**Branch:** `fix/f48a` | **Status:** P1 merged; P2 awaiting approve phase P2

---

## Assumptions

- F48bde is already merged: `qibla_instruction_facing`, `qibla_instruction_close`, `qibla_instruction_turn`, `qibla_hold_flat` exist in both translation files.
- `_qiblaDirection` and `_heading` are `double?` nullable instance fields in `_QiblaScreenState`.
- No behavior change is introduced to the compass dial itself — only the instruction text logic.

---

## Finding

### F48a — `_buildInstructions` discards sign and breaks 0/360 wrap (MEDIUM)

`qibla_screen.dart` lines 357–358:
```dart
final headingDiff = _qiblaDirection != null && _heading != null
    ? (_qiblaDirection! - _heading!).abs()
    : 0.0;
```

**Bug 1 — wrong wrap at 0°/360° boundary.**  
When qibla = 5° and heading = 355°, raw diff = 5 − 355 = −350. After `.abs()` = 350°.  
The user is only 10° away from Qibla but sees "Turn" instead of "Close to Qibla".

**Bug 2 — direction discarded.**  
`.abs()` throws away the sign, so the code can never tell left from right. The `else` branch always falls through to `qibla_instruction_turn`, which says "Turn to the right" — wrong half the time.

---

## Fix

Replace the unsigned `headingDiff` with a signed, wrap-corrected `angleDiff`:

```dart
final angleDiff = _qiblaDirection != null && _heading != null
    ? ((_qiblaDirection! - _heading!) + 540) % 360 - 180
    : 0.0;
```

Formula derivation: `+540 = +360 + 180` shifts the raw diff (range [−360, 360]) into [180, 900], `% 360` folds to [0, 360), `- 180` centres to [−180, 180). Positive = clockwise (turn right), negative = anti-clockwise (turn left). When the user faces exactly opposite Qibla (raw diff = ±180°), `angleDiff` = −180 and "turn left" is chosen — intentional tie-break.

Replace the branching block:

```dart
if (angleDiff.abs() < 5) {
  instruction = 'qibla_instruction_facing'.tr();
  instructionColor = Colors.green;
} else if (angleDiff.abs() < 20) {
  instruction = 'qibla_instruction_close'.tr();
  instructionColor = Colors.orange;
} else if (angleDiff > 0) {
  instruction = 'qibla_instruction_turn_right'.tr();
  instructionColor = Colors.grey;
} else {
  instruction = 'qibla_instruction_turn_left'.tr();
  instructionColor = Colors.grey;
}
```

`qibla_instruction_turn` (added by F48bde) is renamed to `qibla_instruction_turn_right`; its English and Arabic text is kept as-is. A new `qibla_instruction_turn_left` key is added.

---

## Translation keys

### Renamed (content unchanged)

| Old key | New key | en | ar |
|---|---|---|---|
| `qibla_instruction_turn` | `qibla_instruction_turn_right` | Turn to the right | دور نحو اليمين |

### New key

| Key | en | ar |
|---|---|---|
| `qibla_instruction_turn_left` | Turn to the left | دور نحو اليسار |

---

## Files changed

| File | Change |
|---|---|
| `lib/features/qibla/qibla_screen.dart` | Replace `headingDiff`/`.abs()` with signed `angleDiff`; replace `qibla_instruction_turn` with `qibla_instruction_turn_right`/`qibla_instruction_turn_left` |
| `assets/translations/en.json` | Delete `qibla_instruction_turn`; insert `qibla_instruction_turn_right` and `qibla_instruction_turn_left` adjacent to `qibla_instruction_close` (line 652) |
| `assets/translations/ar.json` | Delete `qibla_instruction_turn`; insert `qibla_instruction_turn_right` and `qibla_instruction_turn_left` adjacent to `qibla_instruction_close` (line 652) |
| `test/features/qibla/f48a_source_test.dart` | New — 5 tests (see below) |

---

## Tests

**T1 — wrap at 0°/360° boundary (close):**  
`qibla = 5.0, heading = 355.0` → `angleDiff = (5−355+540)%360−180 = 190%360−180 = 10.0` → `abs = 10 < 20` → "close".

**T2 — turn right:**  
`qibla = 90.0, heading = 45.0` → `angleDiff = (90−45+540)%360−180 = 585%360−180 = 45.0` → `> 0` → "turn right".

**T3 — turn left:**  
`qibla = 45.0, heading = 90.0` → `angleDiff = (45−90+540)%360−180 = 495%360−180 = −45.0` → `< 0` → "turn left".

**T4 — exact facing:**  
`qibla = 180.0, heading = 180.0` → `angleDiff = (0+540)%360−180 = 180−180 = 0.0` → `abs < 5` → "facing".

**T5 — exact opposite (±180° tie-break):**  
`qibla = 180.0, heading = 0.0` → `angleDiff = (180−0+540)%360−180 = 720%360−180 = −180.0` → `< 0` → "turn left".

Tests use a pure function extracted from the branch logic (no Flutter dependency). `classifyAngle` is defined as a file-private helper inside `f48a_source_test.dart`; it is not extracted into production code.

```dart
String classifyAngle(double qibla, double heading) {
  final d = ((qibla - heading) + 540) % 360 - 180;
  if (d.abs() < 5) return 'facing';
  if (d.abs() < 20) return 'close';
  if (d > 0) return 'right';
  return 'left';
}
```

---

## Alternatives considered

**`((qibla - heading) % 360 + 360) % 360 - 180` vs `+540` shortcut**  
These are NOT equivalent in Dart. Dart's `double % double` uses truncated (not floored) division, so `45.0 % 360.0 = 45.0` and the `+360` step does nothing for positive raw diffs: the alternative maps d=45 to −135 instead of +45. The `+540` shortcut avoids this entirely because the input to `%` is always in [180, 900] (always positive), where truncated and floored modulo agree. Chosen: `+540`.

**Keep `qibla_instruction_turn` and add a new `_left` key only**  
Would leave an ambiguous generic "turn" key in the bundle with no call site. Rename to `_right` is cleaner. Chosen: rename + add.

---

## Contract check

| Contract | Verdict |
|---|---|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| Translation keys | `qibla_instruction_turn` renamed to `qibla_instruction_turn_right`; `qibla_instruction_turn_left` added |
| New prefs keys introduced | None |

---

## Device check

**S-F48a-1** — PASS nova 5T 2026-11-28 (all directions, boundary, and facing confirmed by user rotation).

---

## P2 — Haptic feedback on facing Qibla

### Finding

No physical feedback when the user reaches the Qibla direction; the instruction text colour change alone is easy to miss while the phone is moving.

### Fix

Vibrate once (short pulse) when `angleDiff.abs()` crosses the 5° threshold from above: transitioning from "not facing" to "facing". Do **not** vibrate continuously while already facing — only on the edge.

**New state field** (`_QiblaScreenState`):
```dart
bool _isFacing = false;
```

**In the compass stream listener** (after the smoothing block, before `setState`):
```dart
final newIsFacing = _qiblaDirection != null
    ? (((_qiblaDirection! - _smoothedHeading) + 540) % 360 - 180).abs() < 5
    : false;
if (newIsFacing && !_isFacing) {
  _onFacingQibla();
}
_isFacing = newIsFacing;
```

**New helper** (Android-only gate, matches `AdhanPlayerService` pattern):
```dart
Future<void> _onFacingQibla() async {
  try {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 200, amplitude: 128);
    }
  } catch (_) {}
}
```

**New import**: `package:vibration/vibration.dart` (already in `pubspec.yaml` at `^2.0.0`).

### Files changed (P2)

| File | Change |
|---|---|
| `lib/features/qibla/qibla_screen.dart` | Add `_isFacing` field, transition check in listener, `_onFacingQibla()` helper, vibration import |

### No new translation keys, prefs keys, or contracts.

### Device check

**S-F48a-2** — Open Qibla screen. Face away from Qibla, then rotate toward it:
- One short vibration fires at the moment the "You are facing Qibla" text appears.
- No continuous vibration while holding the phone on Qibla.
- Rotate away and back: a second vibration fires on re-entry.
