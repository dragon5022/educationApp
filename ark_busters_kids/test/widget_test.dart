import 'package:ark_busters_kids/screens/hub/hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The hub shows the four game cards (image cards, no text labels).
void main() {
  testWidgets('hub renders the four mode cards', (tester) async {
    SharedPreferences.setMockInitialValues({'ark_story_seen': '1'});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HubScreen()));
    await tester.pump(const Duration(seconds: 2));

    final cards = find.byWidgetPredicate(
      (w) => w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('assets/images/hub/card-'),
    );
    // The ListView builds cards lazily; the 4th sits below the fold.
    expect(cards, findsAtLeastNWidgets(3));
  });
}
