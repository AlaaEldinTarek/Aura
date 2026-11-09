import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/providers/guest_migration_provider.dart';

// F60: the sync offer must reflect the stored flag after refresh(), and only
// for the signed-in account that the flag names.
const _key = 'pending_guest_migration_uid';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int localCount;
  late String? signedInUid;
  late List<String> uploads;

  GuestMigrationNotifier build() => GuestMigrationNotifier(
        localTaskCount: () async => localCount,
        currentUid: () => signedInUid,
        migrateTasks: (uid) async => uploads.add(uid),
      );

  Future<String?> storedFlag() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  setUp(() {
    localCount = 2;
    signedInUid = 'u1';
    uploads = [];
  });

  test('matching uid: pending with uid and count', () async {
    SharedPreferences.setMockInitialValues({_key: 'u1'});
    final n = build();
    await n.refresh();
    expect(n.state.isPending, isTrue);
    expect(n.state.uid, 'u1');
    expect(n.state.taskCount, 2);
  });

  test('different uid: not pending, flag kept, no upload', () async {
    SharedPreferences.setMockInitialValues({_key: 'u1'});
    signedInUid = 'u2';
    final n = build();
    await n.refresh();
    expect(n.state.isPending, isFalse);
    expect(await storedFlag(), 'u1');
    await n.migrate();
    expect(uploads, isEmpty);
  });

  test('not signed in: not pending, flag kept', () async {
    SharedPreferences.setMockInitialValues({_key: 'u1'});
    signedInUid = null;
    final n = build();
    await n.refresh();
    expect(n.state.isPending, isFalse);
    expect(await storedFlag(), 'u1');
  });

  test('flag written after creation (sign-in in the same session)', () async {
    SharedPreferences.setMockInitialValues({});
    final n = build();
    await n.refresh();
    expect(n.state.isPending, isFalse);

    await (await SharedPreferences.getInstance()).setString(_key, 'u1');
    await n.refresh();
    expect(n.state.isPending, isTrue);
  });

  test('count 0 with matching uid: not pending, flag cleared', () async {
    SharedPreferences.setMockInitialValues({_key: 'u1'});
    localCount = 0;
    final n = build();
    await n.refresh();
    expect(n.state.isPending, isFalse);
    expect(await storedFlag(), isNull);
  });

  test('refresh keeps dialogShownThisSession', () async {
    SharedPreferences.setMockInitialValues({_key: 'u1'});
    final n = build();
    await n.refresh();
    n.markDialogShown();
    await n.refresh();
    expect(n.state.dialogShownThisSession, isTrue);
    expect(n.state.isPending, isTrue);
  });

  test('no flag: not pending', () async {
    SharedPreferences.setMockInitialValues({});
    final n = build();
    await n.refresh();
    expect(n.state.isPending, isFalse);
  });

  test('matching uid: migrate uploads once and clears the flag', () async {
    SharedPreferences.setMockInitialValues({_key: 'u1'});
    final n = build();
    await n.refresh();
    await n.migrate();
    expect(uploads, ['u1']);
    expect(await storedFlag(), isNull);
    expect(n.state.isPending, isFalse);
  });
}
