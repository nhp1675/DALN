import 'screens/settings.dart';
import 'screens/snacks.dart';
import 'screens/commerce_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'widgets/common.dart';
import 'screens/catalog.dart';
import 'screens/booking.dart';
import 'screens/account.dart';
import 'screens/tickets.dart';
import 'screens/cinemas_chat.dart';
import 'screens/admin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(Api());
  runApp(CineGoApp(session: session));
  session.initialize();
}

OutlineInputBorder _outline(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final edge = dark ? const Color(0x4DFFFFFF) : const Color(0xFFD9D4CB);
  final scheme = ColorScheme.fromSeed(
    seedColor: coral,
    brightness: brightness,
    primary: dark ? const Color(0xFFFF6B58) : coral,
    onPrimary: dark ? const Color(0xFF1A0805) : Colors.white,
    surface: dark ? nightRaised : Colors.white,
    onSurface: dark ? const Color(0xFFEDF1F5) : null,
    onSurfaceVariant: dark ? const Color(0xFFB4BEC9) : null,
    outlineVariant: dark ? const Color(0xFF2E3946) : null,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: dark ? night : paper,
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0x33FFFFFF) : hairline,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? night : Colors.white,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      shape: Border(
        bottom: BorderSide(color: dark ? const Color(0x33FFFFFF) : hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? nightRaised : Colors.white,
      contentPadding: const EdgeInsets.all(16),
      border: _outline(edge),
      enabledBorder: _outline(edge),
      focusedBorder: _outline(dark ? const Color(0xFFFF6B58) : coral, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: edge),
        foregroundColor: dark ? Colors.white : ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: dark
            ? const Color(0x33FF6B58)
            : const Color(0xFFFCE7E4),
        selectedForegroundColor: dark ? const Color(0xFFFFB4A8) : coral,
        side: BorderSide(color: edge),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF263241) : ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? nightRaised : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class CineGoApp extends StatelessWidget {
  final Session session;
  const CineGoApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appearance,
    builder: (context, mode, child) => AppScope(
      session: session,
      child: MaterialApp(
        title: 'CineGo',
        themeMode: mode,
        darkTheme: _buildTheme(Brightness.dark),
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: _buildTheme(Brightness.light),
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');
          final parts = uri.pathSegments;
          Widget screen;
          bool protected = false, admin = false;
          if (parts.isEmpty) {
            screen = CatalogScreen(cinema: uri.queryParameters['cinema']);
          } else {
            switch (parts.first) {
              case 'movies':
                screen = MovieScreen(
                  id: parts.length > 1 ? parts[1] : '',
                  initialCinema: uri.queryParameters['cinema'],
                );
              case 'booking':
                protected = true;
                screen = BookingScreen(
                  id: parts.length > 1 ? parts[1] : '',
                  exchangeId: uri.queryParameters['exchange'],
                );
              case 'checkout':
                protected = true;
                screen = CheckoutScreen(
                  id: parts.length > 1 ? parts[1] : '',
                  result: uri.queryParameters['payment'],
                );
              case 'tickets':
                protected = true;
                screen = TicketsScreen(
                  paymentResult: uri.queryParameters['payment'],
                );
              case 'cinemas':
                screen = const CinemasScreen();
              case 'chat':
                protected = true;
                screen = ChatScreen(id: parts.length > 1 ? parts[1] : '');
              case 'settings':
                screen = const SettingsScreen();
              case 'snacks':
                protected = true;
                screen = SnacksScreen(paymentResult: uri.queryParameters['payment']);
              case 'commerce-admin':
                protected = true;
                admin = true;
                screen = const CommerceAdminScreen();
              case 'profile':
                protected = true;
                screen = const ProfileScreen();
              case 'admin':
                protected = true;
                admin = true;
                screen = const AdminScreen();
              case 'login':
                screen = AuthScreen(next: uri.queryParameters['next'] ?? '/');
              case 'register':
                screen = AuthScreen(
                  register: true,
                  next: uri.queryParameters['next'] ?? '/',
                );
              case 'forgot-password':
                screen = const ForgotPasswordScreen();
              case 'reset-password':
                screen = ResetPasswordScreen(
                  token: uri.queryParameters['token'] ?? '',
                );
              default:
                screen = const Empty('Trang không tồn tại.');
            }
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => Shell(
              child: Guard(
                required: protected,
                admin: admin,
                next: settings.name ?? '/',
                child: screen,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class Guard extends StatelessWidget {
  final bool required, admin;
  final String next;
  final Widget child;
  const Guard({
    super.key,
    required this.required,
    required this.admin,
    required this.next,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (required && s.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (required && s.user == null) return AuthScreen(next: next);
    if (admin && !s.isAdmin) return const Empty('Bạn không có quyền quản trị.');
    return child;
  }
}

class _NavLink extends StatelessWidget {
  final String label, route;
  final bool active;
  const _NavLink(this.label, this.route, {required this.active});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => go(context, route),
    style: TextButton.styleFrom(
      foregroundColor: active
          ? coral
          : Theme.of(context).colorScheme.onSurface,
      textStyle: TextStyle(
        fontSize: 15,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    child: Text(label),
  );
}

class Shell extends StatelessWidget {
  final Widget child;
  const Shell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width > 1050;
    final current = ModalRoute.of(context)?.settings.name ?? '/';
    bool on(String route) => route == '/'
        ? current == '/' || current.startsWith('/?') || current.startsWith('/movies')
        : current.startsWith(route);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: wide ? 32 : 16,
        automaticallyImplyLeading: false,
        title: InkWell(
          onTap: () => go(context, '/'),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoMark(size: 38),
                const SizedBox(width: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Cine',
                        style: TextStyle(color: onSurface),
                      ),
                      const TextSpan(
                        text: 'Go',
                        style: TextStyle(color: coral),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -.6,
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        actions: [
          if (wide) ...[
            _NavLink('Phim', '/', active: on('/')),
            _NavLink('Hệ thống rạp', '/cinemas', active: on('/cinemas')),
            _NavLink('Bỏng nước', '/snacks', active: on('/snacks')),
            _NavLink('Vé của tôi', '/tickets', active: on('/tickets')),
            if (s.isAdmin) _NavLink('Quản trị', '/admin', active: on('/admin')),
            const SizedBox(width: 12),
            if (MediaQuery.sizeOf(context).width > 1180) OutlinedButton.icon(
              onPressed: () => go(context, '/cinemas'),
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: const Text('Tìm rạp gần bạn'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (s.user == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(
                onPressed: () => go(context, '/login'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Đăng nhập'),
              ),
            )
          else
            IconButton(
              tooltip: 'Tài khoản',
              onPressed: () => go(context, '/profile'),
              icon: const Icon(Icons.person_outline),
            ),
          PopupMenuButton<String>(
            tooltip: 'Mở menu',
            onSelected: (v) async {
              if (v == 'logout') {
                try {
                  await s.logout();
                  if (context.mounted) go(context, '/');
                } catch (e) {
                  if (context.mounted) notice(context, '$e');
                }
              } else {
                go(context, v);
              }
            },
            itemBuilder: (context) => [
              if (!wide) const PopupMenuItem(value: '/', child: Text('Phim')),
              if (!wide)
                const PopupMenuItem(
                  value: '/cinemas',
                  child: Text('Hệ thống rạp'),
                ),
              if (!wide)
                const PopupMenuItem(value: '/snacks', child: Text('Bỏng nước')),
              if (!wide)
                const PopupMenuItem(
                  value: '/tickets',
                  child: Text('Vé của tôi'),
                ),
              if (!wide && s.isAdmin)
                const PopupMenuItem(value: '/admin', child: Text('Quản trị')),
              if (!wide) const PopupMenuDivider(),
              const PopupMenuItem(value: '/settings', child: Text('Cài đặt')),
              if (s.isAdmin)
                const PopupMenuItem(
                  value: '/commerce-admin',
                  child: Text('Kho, nhận hàng & doanh thu'),
                ),
              if (s.user != null) const PopupMenuDivider(),
              if (s.user != null)
                const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: child,
    );
  }
}
