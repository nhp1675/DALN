import 'package:flutter_test/flutter_test.dart';
import 'package:cinego/core/cinema_groups.dart';

void main() {
  test('Long Biên is grouped under Hà Nội and HCM aliases are normalized', () {
    final groups = groupCinemasByCity([
      {'name': 'CineGo Long Biên', 'city': 'Long Biên'},
      {'name': 'CineGo Hồ Chí Minh', 'city': 'TP. HCM'},
      {'name': 'CineGo Hà Nội', 'city': 'Hà Nội'},
      {'name': 'CineGo Đà Nẵng', 'city': 'Đà Nẵng'},
      {'name': 'CineGo Thái Nguyên', 'city': 'Thái Nguyên'},
    ]);
    expect(groups.keys, ['Hà Nội', 'Hồ Chí Minh', 'Đà Nẵng', 'Thái Nguyên']);
    expect(groups['Hà Nội']!.length, 2);
  });
  test('Show dates use Vietnam time and order each date chronologically', () {
    final groups = groupShowtimesByDate([
      {'startAt': '2026-11-05T18:00:00Z'},
      {'startAt': '2026-11-05T09:00:00Z'},
      {'startAt': '2026-11-05T17:00:00Z'},
    ]);
    expect(groups.keys, ['2026-11-05', '2026-11-06']);
    expect(groups['2026-11-06']!.first['startAt'], '2026-11-05T17:00:00Z');
    expect(showDateLabel('2026-11-30'), 'Thứ hai, 30/11/2026');
  });
  test('Empty cinema and show lists produce empty groups', () {
    expect(groupCinemasByCity([]), isEmpty);
    expect(groupShowtimesByDate([]), isEmpty);
  });
}
