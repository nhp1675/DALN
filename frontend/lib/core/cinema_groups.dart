import 'api.dart';

String cinemaCity(Json cinema) {
  final city = sid(cinema['city']).trim();
  final key = city.toLowerCase().replaceAll(RegExp(r'[.\s]'), '');
  if (sid(cinema['name']).trim().toLowerCase() == 'cinego long biên' ||
      [
        'longbiên',
        'longbien',
        'hànội',
        'hanoi',
        'tphànội',
        'thànhphốhànội',
      ].contains(key)) {
    return 'Hà Nội';
  }
  if ([
    'hồchíminh',
    'hochiminh',
    'tphồchíminh',
    'thànhphốhồchíminh',
    'tphcm',
    'hcm',
    'sàigòn',
  ].contains(key)) {
    return 'Hồ Chí Minh';
  }
  if (['đànẵng', 'danang', 'tpđànẵng', 'thànhphốđànẵng'].contains(key)) {
    return 'Đà Nẵng';
  }
  if ([
    'tháinguyên',
    'thainguyen',
    'tptháinguyên',
    'thànhphốtháinguyên',
  ].contains(key)) {
    return 'Thái Nguyên';
  }
  return city.isEmpty ? 'Khác' : city;
}

Map<String, List<Json>> groupCinemasByCity(List<Json> cinemas) {
  final groups = <String, List<Json>>{};
  for (final cinema in cinemas) {
    groups.putIfAbsent(cinemaCity(cinema), () => <Json>[]).add(cinema);
  }
  const order = ['Hà Nội', 'Hồ Chí Minh', 'Đà Nẵng', 'Thái Nguyên'];
  final cities = groups.keys.toList()
    ..sort((a, b) {
      final ai = order.indexOf(a), bi = order.indexOf(b);
      if (ai >= 0 || bi >= 0) {
        return (ai < 0 ? order.length : ai).compareTo(
          bi < 0 ? order.length : bi,
        );
      }
      return a.compareTo(b);
    });
  return {for (final city in cities) city: groups[city]!};
}

String showDateKey(Json show) {
  final at = DateTime.tryParse(sid(show['startAt']));
  return at == null
      ? ''
      : at
            .toUtc()
            .add(const Duration(hours: 7))
            .toIso8601String()
            .substring(0, 10);
}

Map<String, List<Json>> groupShowtimesByDate(List<Json> shows) {
  final groups = <String, List<Json>>{};
  for (final show in shows) {
    groups.putIfAbsent(showDateKey(show), () => <Json>[]).add(show);
  }
  final days = groups.keys.toList()..sort();
  return {
    for (final day in days)
      day: groups[day]!
        ..sort((a, b) {
          final at = DateTime.tryParse(sid(a['startAt'])),
              bt = DateTime.tryParse(sid(b['startAt']));
          return at == null || bt == null ? 0 : at.compareTo(bt);
        }),
  };
}

String showDateLabel(String key) {
  final date = DateTime.tryParse(key);
  if (date == null) {
    return 'Chưa xác định ngày';
  }
  const weekdays = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
