import 'package:bomb_timer/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('처음 화면에 점화 버튼이 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BombTimerApp());
    await tester.pump();
    expect(find.text('때지의 스탑워치'), findsWidgets);
    expect(find.text('점화'), findsOneWidget);
    expect(find.text('리셋'), findsOneWidget);
  });
}
