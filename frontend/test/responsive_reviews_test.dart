import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cinego/core/api.dart';
import 'package:cinego/core/session.dart';
import 'package:cinego/main.dart';
import 'package:cinego/widgets/common.dart';
import 'package:cinego/widgets/movie_reviews.dart';

import 'app_test.dart' as base;

void main() {
  final sizes = <Size>[
    const Size(320, 689),
    const Size(360, 740),
    const Size(390, 844),
    const Size(600, 800),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1200, 800),
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(2560, 1440),
    const Size(844, 390),
  ];
  for (final size in sizes) {
    testWidgets('Responsive routes at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = base.Fixture(admin: true);
      fixture.tickets = [
        for (var i = 0; i < 2; i++)
          {
            '_id': '${777 + i}'.padLeft(24, '7'),
            'orderId': base.orderId,
            'showtimeId': base.showId,
            'showtimeSeatId': fixture.seats[i]['id'],
            'currentValue': 80000,
            'status': 'valid',
            'policy': fixture.policy,
            'qr': 'ticket-qr-$i',
          },
      ];
      final api = Api(
        client: MockClient((req) async {
          final path = req.url.path.replaceFirst('/api', '');
          dynamic result;
          if (path.endsWith('/reviews')) {
            result = {
              'items': [
                {
                  '_id': 'review',
                  'name':
                      'Tên khách hàng dài để kiểm tra bố cục trên điện thoại',
                  'rating': 5,
                  'comment': 'Phim có nội dung thú vị. ' * 20,
                  'createdAt': '2026-01-01T00:00:00Z',
                },
              ],
              'movies': [fixture.movie],
              'mine': null,
              'canReview': true,
              'average': 5,
              'total': 1,
              'counts': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 1},
              'pages': 1,
            };
          } else if (path == '/tickets') {
            result = {
              'tickets': fixture.tickets,
              'shows': [fixture.show],
              'movies': [fixture.movie],
              'cinemas': [fixture.cinema],
              'seats': fixture.seats,
              'refunds': [],
              'snackLines': [
                {
                  '_id': 'snack-line',
                  'orderId': base.orderId,
                  'showtimeId': base.showId,
                  'name': 'Trà đào 500 ml',
                  'image': '',
                  'price': 25000,
                  'quantity': 1,
                  'remaining': 1,
                  'collected': false,
                  'pickupDate': '2026-11-05',
                  'pickupCode': 'PICKUP123456',
                },
              ],
            };
          } else if (path == '/snack-orders') {
            result = {'lines': []};
          } else if (path == '/chat/${base.showId}/messages') {
            result = [
              {
                '_id': 'm1',
                'userId': 'other',
                'name': 'Khách hàng',
                'body': 'Nội dung tin nhắn dài. ' * 30,
                'createdAt': '2026-01-01T00:00:00Z',
              },
            ];
          } else if (path == '/admin/snacks' ||
              path == '/admin/snack-pickups') {
            result = [];
          } else if (path == '/admin/revenue') {
            result = {
              'totals': {'received': 120000, 'returned': 0},
              'days': [
                {'day': '2026-01-01', 'received': 120000},
              ],
              'reconciliation': [],
              'entries': [],
            };
          } else {
            return http.Response.fromStream(await fixture.api.client.send(req));
          }
          return http.Response(
            jsonEncode(result),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final session = Session(api);
      await session.initialize();
      await tester.pumpWidget(CineGoApp(session: session));
      await tester.pumpAndSettle();
      final routes = [
        '/movies/${base.movieId}',
        '/tickets',
        '/chat',
        '/chat/${base.showId}',
        '/cinemas',
        '/snacks',
        '/profile',
        '/admin',
        '/commerce-admin',
        '/settings',
      ];
      for (final route in routes) {
        final nav = Navigator.of(tester.element(find.byType(Shell).last));
        nav.pushReplacementNamed(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$route at $size');
        if (route == '/tickets') {
          await tester.tap(find.text('Chi tiết ghế và mã QR'));
          await tester.pumpAndSettle();
          expect(find.text('Tải mã QR'), findsNWidgets(2));
          expect(tester.takeException(), isNull);
        }
        if (route == '/chat/${base.showId}') {
          expect(find.text('Rời phòng'), findsNothing);
          expect(find.textContaining('Enter để gửi'), findsNothing);
          expect(
            find.byTooltip('Quay lại danh sách phòng chat'),
            findsOneWidget,
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
      fixture.api.close();
    });
  }
  testWidgets(
    'Review editor sends selected stars and comment, never supplied owner',
    (tester) async {
      Json? sent;
      final api = Api(
        client: MockClient((req) async {
          dynamic result;
          if (req.method == 'PUT') {
            sent = asMap(jsonDecode(req.body));
            result = {'ok': true};
          } else {
            result = {
              'items': [],
              'mine': null,
              'canReview': true,
              'average': 0,
              'total': 0,
              'counts': {},
              'pages': 1,
            };
          }
          return http.Response(jsonEncode(result), 200);
        }),
      );
      final session = Session(api)..user = {'id': 'customer'};
      await tester.pumpWidget(
        AppScope(
          session: session,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MovieReviews(movieId: 'film')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4 sao'));
      await tester.enterText(find.byType(TextField), 'Rất hay');
      await tester.ensureVisible(find.text('Gửi đánh giá'));
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(sent, {'rating': 4, 'comment': 'Rất hay'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
      session.dispose();
    },
  );
}
