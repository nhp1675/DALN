import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cinego/core/api.dart';
import 'package:cinego/core/session.dart';
import 'package:cinego/main.dart';
import 'package:cinego/screens/cinemas_chat.dart';
import 'package:cinego/screens/moderation.dart';
import 'package:cinego/widgets/common.dart';

const movieId = '111111111111111111111111',
    showId = '222222222222222222222222',
    cinemaId = '333333333333333333333333',
    orderId = '444444444444444444444444';

class Fixture {
  final calls = <http.Request>[];
  final policy = {
    'holdMinutes': 10,
    'changeCutoffHours': 24,
    'refundPercent': 100,
    'pointsPerVnd': 10000,
  };
  late final Json movie = {
    '_id': movieId,
    'title': 'Quỹ đạo cuối cùng',
    'genre': 'Khoa học viễn tưởng',
    'duration': 128,
    'synopsis': 'Một chuyến đi tới hành tinh xa.',
    'director': 'Trần Hải',
    'cast': 'Minh Anh',
    'ageRating': 'T13',
    'status': 'now',
    'poster': '/posters/orbit.svg',
  };
  final Json cinema = {
    '_id': cinemaId,
    'name': 'CineGo Hà Đông',
    'address': 'Hà Đông, Hà Nội',
    'city': 'Hà Nội',
    'latitude': 21.0,
    'longitude': 105.8,
  };
  late final Json show = {
    '_id': showId,
    'movieId': movieId,
    'cinemaId': cinemaId,
    'roomId': '555555555555555555555555',
    'startAt': DateTime.now()
        .add(const Duration(days: 3))
        .toUtc()
        .toIso8601String(),
    'endAt': DateTime.now()
        .add(const Duration(days: 3, hours: 2))
        .toUtc()
        .toIso8601String(),
    'standardPrice': 80000,
    'vipPrice': 110000,
    'status': 'active',
  };
  late final seats = List.generate(
    10,
    (i) => {
      'id': '${100 + i}'.padLeft(24, '0'),
      '_id': '${100 + i}'.padLeft(24, '0'),
      'label': 'A${i + 1}',
      'price': 80000,
      'type': 'standard',
      'status': i == 4 ? 'booked' : 'available',
    },
  );
  Json? order;
  List<Json> tickets = [];
  bool locked = false, hidden = false, banned = false;
  bool admin;
  Fixture({this.admin = false});
  late final Api api = Api(
    client: MockClient((request) async {
      calls.add(request);
      final path = request.url.path.replaceFirst('/api', '');
      dynamic result;
      if (path == '/config') {
        result = {'paymentMode': 'demo', 'policy': policy};
      } else if (path == '/auth/me') {
        result = {
          'user': {
            'id': '666666666666666666666666',
            'name': 'Nguyễn Hồng Phong',
            'email': 'phong@example.test',
            'phone': '',
            'role': admin ? 'admin' : 'customer',
            'points': 8,
          },
          'csrf': 'test-csrf',
        };
      } else if (path == '/movies') {
        result = [movie];
      } else if (path == '/movies/$movieId') {
        result = movie;
      } else if (path == '/cinemas') {
        result = [cinema];
      } else if (path == '/showtimes') {
        result = [show];
      } else if (path == '/showtimes/$showId/seats') {
        result = {
          'showtime': show,
          'seats': seats,
          'room': {'name': 'Phòng 01 · 2D'},
        };
      } else if (path == '/orders' && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map;
        final chosen = seats
            .where((s) => (body['seatIds'] as List).contains(s['id']))
            .toList();
        order = {
          '_id': orderId,
          'kind': 'booking',
          'status': 'pending',
          'total': chosen.length * 80000,
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 10))
              .toUtc()
              .toIso8601String(),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'policy': policy,
          'chosen': chosen,
        };
        result = order;
      } else if (path == '/orders') {
        result = order == null ? [] : [order];
      } else if (path == '/orders/$orderId/pay-demo') {
        final b = jsonDecode(request.body) as Map;
        if (b['outcome'] == 'success') {
          order!['status'] = 'paid';
          tickets = [
            {
              '_id': '777777777777777777777777',
              'showtimeId': showId,
              'showtimeSeatId': seats.first['id'],
              'currentValue': 80000,
              'status': 'valid',
              'policy': policy,
              'qr': 'a' * 43,
            },
          ];
        }
        result = order;
      } else if (path == '/orders/$orderId') {
        result = {
          'order': order,
          'movie': movie,
          'show': show,
          'cinema': cinema,
          'seats': order!['chosen'],
          'payments': [],
        };
      } else if (path == '/tickets') {
        result = {
          'tickets': tickets,
          'shows': [show],
          'movies': [movie],
          'cinemas': [cinema],
          'seats': seats,
          'refunds': [],
        };
      } else if (path == '/admin/chat/rooms') {
        result = {
          'items': [
            {'_id': 'room1', 'showtimeId': showId, 'locked': locked},
          ],
          'shows': [show],
          'movies': [movie],
          'cinemas': [cinema],
          'pages': 1,
        };
      } else if (path.startsWith('/admin/chat/rooms/room1/') &&
          request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map;
        if (path.endsWith('/lock')) locked = body['value'] == true;
        if (path.contains('/messages/')) hidden = body['value'] == true;
        if (path.endsWith('/ban')) banned = body['value'] == true;
        result = {'ok': true};
      } else if (path == '/admin/chat/rooms/room1/messages') {
        result = {
          'room': {'_id': 'room1', 'locked': locked},
          'items': [
            {
              '_id': 'msg1',
              'userId': 'user1',
              'name': 'Khách',
              'body': '<script>Văn bản cần kiểm duyệt</script>',
              'hidden': hidden,
            },
          ],
          'bans': banned
              ? [
                  {'userId': 'user1', 'reason': 'Vi phạm nội quy'},
                ]
              : [],
          'pages': 1,
        };
      } else if (path == '/admin/overview') {
        result = {'users': 12, 'tickets': 18, 'pending': 2, 'net': 1750000};
      } else if (path.startsWith('/admin/data/')) {
        final name = path.split('/').last;
        final list =
            {
              'movies': [movie],
              'cinemas': [cinema],
              'rooms': [
                {
                  '_id': '555555555555555555555555',
                  'name': 'Phòng 01',
                  'cinemaId': cinemaId,
                },
              ],
              'showtimes': [show],
            }[name] ??
            [];
        result = {'items': list, 'total': list.length, 'pages': 1, 'page': 1};
      } else {
        return http.Response(
          jsonEncode({'message': 'Unknown fixture: $path'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(result),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  Future<Session> session() async {
    final s = Session(api);
    await s.initialize();
    return s;
  }
}

void main() {
  test('Distance calculation stays local and returns zero at same point', () {
    expect(distanceKm(21, 105, 21, 105), closeTo(0, 0.001));
    expect(distanceKm(21, 105, 22, 105), closeTo(111.19, 0.1));
  });
  test(
    'API sends CSRF and exposes server errors without accepting HTML',
    () async {
      http.Request? captured;
      final api = Api(
        client: MockClient((r) async {
          captured = r;
          return http.Response(
            '{"message":"Không có quyền"}',
            403,
            headers: {"content-type": "application/json; charset=utf-8"},
          );
        }),
      );
      api.csrf = 'secret-csrf';
      await expectLater(
        api.request('/orders', method: 'POST', body: {'x': 1}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      expect(captured!.headers['x-csrf-token'], 'secret-csrf');
      expect(jsonDecode(captured!.body), {'x': 1});
    },
  );
  testWidgets(
    'Moderation requires reason and supports hide, restore, lock and ban',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = Fixture(admin: true);
      final session = await f.session();
      await tester.pumpWidget(
        AppScope(
          session: session,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ModerationPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quỹ đạo cuối cùng'));
      await tester.pumpAndSettle();
      expect(
        find.text('<script>Văn bản cần kiểm duyệt</script>'),
        findsOneWidget,
      );
      Future<void> action(String label) async {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(find.text('Nhập lý do ít nhất 3 ký tự.'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), 'Vi phạm nội quy');
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
      }

      await action('Ẩn tin nhắn');
      expect(f.hidden, isTrue);
      expect(find.text('Đã ẩn khỏi phòng chat'), findsOneWidget);
      await action('Khôi phục');
      expect(f.hidden, isFalse);
      await action('Khóa phòng');
      expect(f.locked, isTrue);
      await action('Mở phòng');
      expect(f.locked, isFalse);
      await action('Chặn thành viên');
      expect(f.banned, isTrue);
      await action('Bỏ chặn');
      expect(f.banned, isFalse);
      expect(f.calls.where((r) => r.method == 'PATCH'), hasLength(6));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Catalog filters and opens film schedule', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = Fixture();
    await tester.pumpWidget(CineGoApp(session: await f.session()));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Tìm rạp gần bạn'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Bản đồ án'), findsNothing);
    expect(find.text('Quỹ đạo cuối cùng'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'không tồn tại');
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có phim phù hợp'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đặt vé').first);
    await tester.tap(find.text('Đặt vé').first);
    await tester.pumpAndSettle();
    expect(find.text('Lịch chiếu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Mobile seats toggle, payment fails then succeeds, QR is issued',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = Fixture();
      await tester.pumpWidget(CineGoApp(session: await f.session()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Shell).first);
      Navigator.of(context).pushNamed('/booking/$showId');
      await tester.pumpAndSettle();
      expect(find.text('Chọn ghế ngồi'), findsOneWidget);
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Thử thanh toán thất bại'));
      await tester.tap(find.text('Thử thanh toán thất bại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Thanh toán thử thất bại'), findsOneWidget);
      await tester.ensureVisible(find.text('Xác nhận thanh toán mô phỏng'));
      await tester.tap(find.text('Xác nhận thanh toán mô phỏng'));
      await tester.pumpAndSettle();
      expect(find.text('Tải mã QR'), findsOneWidget);
      expect(f.tickets, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('Admin renders catalogs and edit dialog', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = Fixture(admin: true);
    await tester.pumpWidget(CineGoApp(session: await f.session()));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Shell).first)).pushNamed('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Quản trị rạp phim'), findsOneWidget);
    await tester.tap(find.text('Thêm mới'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Tên phim'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
