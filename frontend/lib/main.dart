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

class CineGoApp extends StatelessWidget {
  final Session session;
  const CineGoApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => AppScope(
    session: session,
    child: MaterialApp(
      title: 'CineGo — Hẹn nhau ở rạp',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: coral,
          primary: coral,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFFCFBF8),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDADFD8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDADFD8)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
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
              screen = CheckoutScreen(id: parts.length > 1 ? parts[1] : '');
            case 'tickets':
              protected = true;
              screen = const TicketsScreen();
            case 'cinemas':
              screen = const CinemasScreen();
            case 'chat':
              protected = true;
              screen = ChatScreen(id: parts.length > 1 ? parts[1] : '');
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

class Shell extends StatelessWidget {
  final Widget child;
  const Shell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width > 1050;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: wide ? 28 : 16,
        automaticallyImplyLeading: false,
        title: InkWell(
          onTap: () => go(context, '/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: coral,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.movie_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 9),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Cine',
                      style: TextStyle(color: ink),
                    ),
                    TextSpan(
                      text: 'Go',
                      style: TextStyle(color: coral),
                    ),
                  ],
                ),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 27),
              ),
            ],
          ),
        ),
        actions: [
          if (wide) ...[
            TextButton(
              onPressed: () => go(context, '/'),
              child: const Text('Phim'),
            ),
            TextButton(
              onPressed: () => go(context, '/cinemas'),
              child: const Text('Hệ thống rạp'),
            ),
            TextButton.icon(
              onPressed: () => go(context, '/cinemas'),
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: const Text('Tìm rạp gần bạn'),
            ),
            TextButton(
              onPressed: () => go(context, '/tickets'),
              child: const Text('Vé của tôi'),
            ),
            if (s.isAdmin)
              TextButton(
                onPressed: () => go(context, '/admin'),
                child: const Text('Quản trị'),
              ),
            const SizedBox(width: 16),
          ],
          if (s.user == null)
            TextButton.icon(
              onPressed: () => go(context, '/login'),
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Đăng nhập'),
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
              const PopupMenuItem(value: '/', child: Text('Phim')),
              const PopupMenuItem(
                value: '/cinemas',
                child: Text('Hệ thống rạp'),
              ),
              const PopupMenuItem(
                value: '/cinemas',
                child: Text('Tìm rạp gần bạn'),
              ),
              const PopupMenuItem(value: '/tickets', child: Text('Vé của tôi')),
              if (s.isAdmin)
                const PopupMenuItem(value: '/admin', child: Text('Quản trị')),
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
