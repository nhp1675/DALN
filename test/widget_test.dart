// Test cơ bản: đảm bảo app khởi động được và hiển thị màn hình trang chủ.
import 'package:flutter_test/flutter_test.dart';

import 'package:cinema_booking/app.dart';

void main() {
  testWidgets('App khởi động và hiển thị màn hình trang chủ', (WidgetTester tester) async {
    await tester.pumpWidget(const CinemaApp());
    await tester.pump();

    // CineTicket là tiêu đề hiển thị trên AppBar của HomeScreen.
    expect(find.text('CineTicket'), findsWidgets);
  });
}
