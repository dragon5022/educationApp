import 'package:ark_core/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('unavailable: friendly message, account row hidden', (
    tester,
  ) async {
    final auth = ArkAuth();
    await auth.initWithBackends(
      appId: 'kids',
      backend: null,
      observeLifecycle: false,
    );
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArkAccountRow(auth: auth),
            SizedBox(width: 400, height: 600, child: ArkLoginSheet(auth: auth)),
          ],
        ),
      ),
    );
    expect(find.textContaining('ログインしなくても ぜんぶ あそべるよ'), findsOneWidget);
    expect(find.byKey(const ValueKey('ark-login-id')), findsNothing);
    expect(find.byKey(const ValueKey('ark-account-row-value')), findsNothing);
    auth.dispose();
  });

  testWidgets('login form: error, success, logged-in ID, logout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = ArkAuth();
    await auth.initWithBackends(
      appId: 'kids',
      backend: FakeAuthBackend(
        accounts: {'ark001@students.ark-busters.app': 'secret1'},
      ),
      observeLifecycle: false,
    );
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArkAccountRow(auth: auth, onTap: () {}),
            SizedBox(width: 400, height: 640, child: ArkLoginSheet(auth: auth)),
          ],
        ),
      ),
    );
    expect(find.text('ログインしていない'), findsOneWidget);
    expect(find.text('ログインしなくても あそべるよ'), findsOneWidget);

    // empty fields
    await tester.tap(find.byKey(const ValueKey('ark-login-submit')));
    await tester.pump();
    expect(find.text('IDと パスワードを いれてね。'), findsOneWidget);

    // wrong password
    await tester.enterText(
      find.byKey(const ValueKey('ark-login-id')),
      'ark001',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ark-login-password')),
      'nope',
    );
    await tester.tap(find.byKey(const ValueKey('ark-login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ちがうみたい'), findsOneWidget);

    // success
    await tester.enterText(
      find.byKey(const ValueKey('ark-login-password')),
      'secret1',
    );
    await tester.tap(find.byKey(const ValueKey('ark-login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(auth.isSignedIn, isTrue);
    expect(find.byKey(const ValueKey('ark-login-current-id')), findsOneWidget);
    expect(find.text('ark001'), findsNWidgets(2)); // sheet + account row

    // help: account deletion request
    await tester.tap(find.text('アカウントを けしたいときは'));
    await tester.pump();
    expect(find.textContaining('じゅくに つたえてね'), findsOneWidget);

    await tester.tap(find.text('ログアウト'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(auth.isSignedIn, isFalse);
    expect(find.byKey(const ValueKey('ark-login-id')), findsOneWidget);
    auth.dispose();
  });
}
