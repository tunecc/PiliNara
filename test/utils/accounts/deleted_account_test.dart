import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

LoginAccount _account() => LoginAccount(
  BiliCookieJar.fromJson({
    'DedeUserID': '123',
    'bili_jct': 'csrf',
  }),
  'access-key',
  'refresh-token',
);

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pilinara-account-test-');
    Hive.init(tempDir.path);
    GStorage.regAdapter();
    // LoginAccountAdapter.write 会经 LoginAccount.buvid 读 Pref，
    // 取不到时回退到 localCache 的指纹缓存，两个盒都要开
    GStorage.setting = await Hive.openBox('test_setting_deleted_account');
    GStorage.localCache = await Hive.openBox(
      'test_local_cache_deleted_account',
    );
    Accounts.account = await Hive.openBox<LoginAccount>('account');
  });

  setUp(() => Accounts.account.clear());

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('late account changes cannot recreate a deleted account', () async {
    final account = _account();
    await account.onChange();
    expect(Accounts.account.containsKey('123'), isTrue);

    final lateResponse = Completer<void>();
    final persistLateResponse = lateResponse.future.then((_) {
      account.cookieJar.saveFromResponse(
        Uri.parse('https://www.bilibili.com'),
        [Cookie('SESSDATA', 'late-cookie')..setBiliDomain()],
      );
      return account.onChange();
    });

    await account.delete();
    lateResponse.complete();
    await persistLateResponse;

    expect(Accounts.account.containsKey('123'), isFalse);
  });

  test(
    'delete tombstone is active before asynchronous deletion completes',
    () async {
      final account = _account();
      await account.onChange();

      final deletion = account.delete();
      await account.onChange();
      await deletion;

      expect(Accounts.account.containsKey('123'), isFalse);
    },
  );
}
