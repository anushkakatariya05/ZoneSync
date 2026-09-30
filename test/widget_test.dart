import 'package:flutter_test/flutter_test.dart';
import 'package:zonesync/main.dart';

void main() {
  testWidgets('ZoneSync home screen loads', (tester) async {
    await tester.pumpWidget(const ZoneSyncApp());

    expect(find.text('ZoneSync'), findsOneWidget);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Manage Silent Zones'), findsOneWidget);
  });
}