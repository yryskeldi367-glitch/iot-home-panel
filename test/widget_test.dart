// Smoke-test: приложение собирает корневой виджет без падений.
import 'package:flutter_test/flutter_test.dart';

import 'package:home_panel/main.dart';
import 'package:home_panel/app_state.dart';

void main() {
  testWidgets('корневой виджет строится', (WidgetTester tester) async {
    final state = AppState();
    await tester.pumpWidget(HomePanelApp(state: state));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Умный дом'), findsOneWidget);
  });
}
