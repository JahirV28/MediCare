import 'package:flutter_test/flutter_test.dart';
import 'package:medicore_emr/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MediCoreApp());
    expect(find.text('MediCore EMR'), findsWidgets);
  });
}
