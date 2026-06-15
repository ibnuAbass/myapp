import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mpesa_tracker2/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await setupDependencies();
    await tester.pumpWidget(const MpesaTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('M-PESA Tracker'), findsOneWidget);
  });
}
