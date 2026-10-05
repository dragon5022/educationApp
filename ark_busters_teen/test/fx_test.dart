import 'package:ark_busters_teen/screens/stage/stage_fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Host extends StatefulWidget {
  const Host({super.key});
  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  int serial = 0;
  void bump() => setState(() => serial++);
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: BoomText(serial: serial)));
}

void main() {
  testWidgets('boom text plays on serial change', (t) async {
    await t.pumpWidget(const Host());
    expect(find.text('BOOM!'), findsNothing);
    t.state<HostState>(find.byType(Host)).bump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('BOOM!'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('BOOM!'), findsNothing);
  });
}
