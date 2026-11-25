# Fix F41b + F41c — Auth snackbar raw exception + forgot-password inline strings

**Status:** Approved for code (phase P1)
**Branch:** `fix/f41bc` (from main)
**Findings:** F41b (LOW), F41c (LOW)
**Files touched:**
- `lib/features/auth/login_screen.dart`
- `lib/features/auth/signup_screen.dart`
- `assets/translations/en.json`
- `assets/translations/ar.json`

---

## F41b — Problem

Both `login_screen.dart:_showErrorSnackBar` and `signup_screen.dart:_showErrorSnackBar`
pass `e.toString()` directly into the snackbar, which renders the Dart wrapper:

```
Exception: No user found with this email.
```

The `auth_service.dart:_getErrorMessage` already produces a clean English string; the
"Exception: " prefix comes from `throw _getErrorMessage(e)` wrapping it.

## F41b — Fix

Strip the prefix in `_showErrorSnackBar` in both screens:

```dart
void _showErrorSnackBar(String message) {
  final clean = message.startsWith('Exception: ')
      ? message.substring('Exception: '.length)
      : message;
  final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(clean), ...),
  );
  ...
}
```

No translation keys needed. The messages from `auth_service.dart` are already
human-readable English; Arabic localisation of error codes is deferred.

---

## F41c — Problem

`login_screen.dart:_showForgotPasswordDialog` (`:250–317`) has 5 inline EN/AR string sites:

| Line(s) | String |
|---------|--------|
| `:263–264` | `isRTL ? 'سنرسل لك رابط إعادة تعيين كلمة المرور' : 'We\'ll send you a password reset link'` |
| `:273` | `isRTL ? 'البريد الإلكتروني' : 'Email address'` (hintText) |
| `:282` | `isRTL ? 'إلغاء' : 'Cancel'` (AuraButton.ghost label) |
| `:285` | `isRTL ? 'إرسال' : 'Send'` (AuraButton label) |
| `:297–299` | success snackbar `'تم إرسال رابط إعادة التعيين إلى $email'` / `'Reset link sent to $email'` |

Additionally `signup_screen.dart:453` uses key `auth_validation_password_mismatch` which
does not exist in either locale file, so the confirm-password error shows blank.

## F41c — Fix

**New translation keys** (added to both `en.json` and `ar.json`):

```json
// en.json additions
"auth_reset_link_hint": "We'll send you a password reset link",
"auth_email_address": "Email address",
"auth_send": "Send",
"auth_reset_sent": "Reset link sent to {}",
"auth_validation_password_mismatch": "Passwords do not match"
```

```json
// ar.json additions
"auth_reset_link_hint": "سنرسل لك رابط إعادة تعيين كلمة المرور",
"auth_email_address": "البريد الإلكتروني",
"auth_send": "إرسال",
"auth_reset_sent": "تم إرسال رابط إعادة التعيين إلى {}",
"auth_validation_password_mismatch": "كلمات المرور غير متطابقة"
```

**Code changes in `login_screen.dart:_showForgotPasswordDialog`:**

```dart
// line 263 — description
Text('auth_reset_link_hint'.tr(), style: AppTypography.label),

// line 273 — email hint
hintText: 'auth_email_address'.tr(),

// line 282 — Cancel button
AuraButton.ghost(label: 'cancel'.tr(), onPressed: () => Navigator.pop(ctx)),

// line 285 — Send button
AuraButton(label: 'auth_send'.tr(), onPressed: ...),

// line 297 — success snackbar
Text('auth_reset_sent'.tr(args: [email])),
```

The `isRTL` variable used only by those sites is removed from the method.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| New translation keys | 5 added to both locales |

---

## Tests

Source-text test (`test/features/auth/f41bc_source_test.dart`):

- **T1**: `login_screen.dart` contains `startsWith('Exception: ')` (F41b guard present)
- **T2**: `signup_screen.dart` contains `startsWith('Exception: ')` (F41b guard present)
- **T3**: `login_screen.dart` does NOT contain `'سنرسل لك'`; contains `'auth_reset_link_hint'.tr()`

---

## Device checks

| ID | Description |
|----|-------------|
| S-F41b-1 | Trigger a wrong-password login; snackbar shows the message without "Exception: " prefix. |
| S-F41c-1 | Tap "Forgot Password?"; dialog title, hint, Cancel and Send buttons show in both EN and AR. |
| S-F41c-2 | Enter two mismatched passwords in the Sign-Up form; the validation error is not blank. |
