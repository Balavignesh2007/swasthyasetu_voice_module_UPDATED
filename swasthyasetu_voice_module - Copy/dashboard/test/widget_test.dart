import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_admin_dashboard/main.dart';

void main() {
  testWidgets('Unified App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SwasthyaSetuUnifiedApp());
    expect(find.byType(SwasthyaSetuUnifiedApp), findsOneWidget);
  });
}
