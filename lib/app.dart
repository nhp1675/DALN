import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'models/dat_ve.dart';
import 'models/suat_chieu.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/auth/dang_ky_screen.dart';
import 'screens/auth/dang_nhap_screen.dart';
import 'screens/booking/so_do_ghe_screen.dart';
import 'screens/booking/thanh_toan_screen.dart';
import 'screens/chat/phong_chat_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/phim/phim_detail_screen.dart';
import 'screens/rap/rap_gan_day_screen.dart';
import 'screens/ve/doi_ve_screen.dart';
import 'screens/ve/ve_cua_toi_screen.dart';
import 'screens/ve/ve_detail_screen.dart';

class CinemaApp extends StatelessWidget {
  const CinemaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        final duongDanCongKhai = ['/dang-nhap', '/dang-ky'];
        if (auth.dangTai) return null;
        final dangODangNhap = duongDanCongKhai.contains(state.matchedLocation);

        // Các màn hình bắt buộc đăng nhập (tiền điều kiện UC-DV, UC-HDV, UC-PC)
        const canDangNhap = ['/dat-ve', '/thanh-toan', '/ve', '/chat', '/admin'];
        final phaiDangNhap = canDangNhap.any((p) => state.matchedLocation.startsWith(p));

        if (!auth.daDangNhap && phaiDangNhap) return '/dang-nhap';
        if (auth.daDangNhap && dangODangNhap) return '/';
        if (state.matchedLocation.startsWith('/admin') && !auth.laAdmin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/dang-nhap', builder: (c, s) => const DangNhapScreen()),
        GoRoute(path: '/dang-ky', builder: (c, s) => const DangKyScreen()),
        GoRoute(
          path: '/phim/:phimId',
          builder: (c, s) => PhimDetailScreen(phimId: s.pathParameters['phimId']!),
        ),
        GoRoute(
          path: '/dat-ve/:suatId',
          builder: (c, s) => SoDoGheScreen(suatId: s.pathParameters['suatId']!),
        ),
        GoRoute(
          path: '/thanh-toan/:donId',
          builder: (c, s) => ThanhToanScreen(donId: s.pathParameters['donId']!),
        ),
        GoRoute(path: '/ve', builder: (c, s) => const VeCuaToiScreen()),
        GoRoute(
          path: '/ve/chi-tiet',
          builder: (c, s) => VeDetailScreen(ve: s.extra as Ve),
        ),
        GoRoute(
          path: '/ve/doi',
          builder: (c, s) => DoiVeScreen(ve: s.extra as Ve),
        ),
        GoRoute(
          path: '/chat/:suatId',
          builder: (c, s) => PhongChatScreen(
            suatId: s.pathParameters['suatId']!,
            suat: s.extra as SuatChieu?,
          ),
        ),
        GoRoute(path: '/rap-gan-day', builder: (c, s) => const RapGanDayScreen()),
        GoRoute(path: '/admin', builder: (c, s) => const AdminScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'CineTicket — Đặt vé xem phim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.toi,
      routerConfig: router,
    );
  }
}
