import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/api.dart';
import '../core/session.dart';

// Bảng màu CineGo.
const coral = Color(0xFFE23B2B); // đỏ thương hiệu
const ink = Color(0xFF16202A); // xanh đêm (chữ, chân trang)
const muted = Color(0xFF6C7782); // chữ phụ (đủ tương phản trên cả nền sáng và tối)
const gold = Color(0xFFE6C891); // vàng ánh kim, điểm nhấn trên nền tối
const paper = Color(0xFFFAF8F5); // nền giao diện sáng
const night = Color(0xFF0A0E13); // nền giao diện tối
const nightRaised = Color(0xFF10161D); // bề mặt (thẻ, hộp thoại) trên nền tối
const hairline = Color(0xFFE7E3DC); // đường viền mảnh trên nền sáng

// Theo dõi việc chuyển trang (dùng để nhả ghế khi rời trang thanh toán).
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// Thông tin chăm sóc khách hàng ở chân trang: chỉnh sửa tại đây.
const supportHotline = '1900 0000';
const supportEmail = 'support@cinego.example';
const supportHours = '8:00 – 22:00 mỗi ngày';

class AppScope extends InheritedNotifier<Session> {
  const AppScope({super.key, required Session session, required super.child})
    : super(notifier: session);
  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Dấu logo: nút phát màu đỏ.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: coral,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * .68),
  );
}

void go(BuildContext context, String route) =>
    Navigator.of(context).pushNamed(route);
void notice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double width;
  const PageBody({super.key, required this.children, this.width = 1180});
  // Nội dung ở trên, chân trang luôn nằm dưới cùng (kể cả khi nội dung ngắn).
  // Không dùng IntrinsicHeight/SliverFillRemaining vì các màn hình có
  // LayoutBuilder và PageView không tính được kích thước nội tại.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width),
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    ),
  );
}

const _footerHead = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w700,
  fontSize: 15,
  letterSpacing: .3,
);
const _footerText = TextStyle(
  color: Color(0xCCFFFFFF),
  height: 1.6,
  fontSize: 14,
);
const _footerSmall = TextStyle(color: Color(0x99FFFFFF), fontSize: 12.5);
const _footerGold = gold;

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 20.0 : 32.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark ? night : ink,
        border: dark
            ? const Border(top: BorderSide(color: Color(0x26FFFFFF)))
            : null,
      ),
      padding: EdgeInsets.fromLTRB(pad, 40, pad, 22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final blocks = <Widget>[
                    const _FooterBrand(),
                    const _FooterLinks(),
                    const _FooterSupport(),
                    const _FooterPayments(),
                  ];
                  if (box.maxWidth >= 820) {
                    const flex = [5, 3, 4, 3];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < blocks.length; i++) ...[
                          if (i > 0) const SizedBox(width: 32),
                          Expanded(flex: flex[i], child: blocks[i]),
                        ],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final b in blocks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: b,
                        ),
                    ],
                  );
                },
              ),
              const Divider(color: Color(0x26FFFFFF), height: 1),
              const SizedBox(height: 16),
              const Text(
                '© 2026 CineGo. Bảo lưu mọi quyền.',
                style: _footerSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterBrand extends StatelessWidget {
  const _FooterBrand();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LogoMark(size: 40),
          const SizedBox(width: 12),
          const Text(
            'CineGo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'Đặt vé xem phim nhanh chóng, chọn ghế dễ dàng và nhận bỏng nước ngay tại rạp.',
        style: _footerText,
      ),
    ],
  );
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Khám phá', style: _footerHead),
      SizedBox(height: 6),
      _FooterLink('Phim đang chiếu', '/'),
      _FooterLink('Hệ thống rạp', '/cinemas'),
      _FooterLink('Đặt bỏng nước', '/snacks'),
      _FooterLink('Vé của tôi', '/tickets'),
      _FooterLink('Cài đặt', '/settings'),
    ],
  );
}

class _FooterLink extends StatelessWidget {
  final String label, route;
  const _FooterLink(this.label, this.route);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => go(context, route),
    hoverColor: Colors.white10,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_right, size: 16, color: _footerGold),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: _footerText)),
        ],
      ),
    ),
  );
}

class _FooterSupport extends StatelessWidget {
  const _FooterSupport();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Chăm sóc khách hàng', style: _footerHead),
      const SizedBox(height: 10),
      const Text('Hotline CSKH', style: _footerSmall),
      SelectableText(
        supportHotline,
        style: const TextStyle(
          color: _footerGold,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
      ),
      const SizedBox(height: 10),
      const _FooterInfo(Icons.mail_outline, supportEmail),
      const _FooterInfo(Icons.schedule, supportHours),
    ],
  );
}

class _FooterInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FooterInfo(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _footerGold),
        const SizedBox(width: 8),
        Expanded(child: SelectableText(text, style: _footerText)),
      ],
    ),
  );
}

class _FooterPayments extends StatelessWidget {
  const _FooterPayments();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Thanh toán', style: _footerHead),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in const ['VNPay', 'MoMo', 'Thẻ ATM'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x40FFFFFF)),
              ),
              child: Text(
                t,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Giao dịch xử lý qua cổng thanh toán đối tác.',
        style: _footerSmall,
      ),
    ],
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? nightRaised
          : (color ?? Colors.white),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0x38FFFFFF)
            : hairline,
      ),
    ),
    child: child,
  );
}

class Heading extends StatelessWidget {
  final String title, eyebrow;
  final Widget? action;
  const Heading(this.title, {super.key, this.eyebrow = '', this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow.isNotEmpty) ...[
              Text(
                eyebrow,
                style: const TextStyle(
                  color: coral,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width < 600 ? 27 : 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class ErrorNote extends StatelessWidget {
  final String? message;
  const ErrorNote(this.message, {super.key});
  @override
  Widget build(BuildContext context) => message == null || message!.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDE9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message!,
                style: const TextStyle(color: Color(0xFF992D24)),
              ),
            ),
          ),
        );
}

class Empty extends StatelessWidget {
  final String text;
  const Empty(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.local_movies_outlined, size: 40, color: muted),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
        ],
      ),
    ),
  );
}

class DataView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T) builder;
  final VoidCallback? retry;
  const DataView({
    super.key,
    required this.future,
    required this.builder,
    this.retry,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(64),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (s.hasError) {
        return Column(
          children: [
            ErrorNote('${s.error}'),
            if (retry != null)
              OutlinedButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
          ],
        );
      }
      if (!s.hasData) return const Empty('Chưa có dữ liệu.');
      return builder(s.data as T);
    },
  );
}

/// Ảnh món bỏng nước. Không có ảnh (hoặc ảnh lỗi) thì dùng ảnh minh họa theo tên món.
class SnackImage extends StatelessWidget {
  final String url, name;
  final double? width, height;
  final double radius;
  const SnackImage({
    super.key,
    required this.url,
    required this.name,
    this.width,
    this.height,
    this.radius = 12,
  });

  static String kind(String name) {
    final n = name.toLowerCase();
    if (n.contains('combo')) return 'combo';
    if (n.contains('bắp') || n.contains('bỏng') || n.contains('popcorn')) {
      return 'popcorn';
    }
    if (RegExp(r'nước|coca|cola|pepsi|sprite|fanta|trà|tea|soda').hasMatch(n)) {
      return 'drink';
    }
    return 'snack';
  }

  Widget _fallback() => SvgPicture.asset(
    'assets/snacks/${kind(name)}.svg',
    fit: BoxFit.cover,
  );

  @override
  Widget build(BuildContext context) {
    final image = url.startsWith('https://')
        ? Image.network(
            url,
            key: ValueKey(url),
            // Cho phép ảnh từ website khác (không cần CORS), giống poster phim.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _fallback(),
          )
        : _fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: image),
    );
  }
}

class Poster extends StatelessWidget {
  final Json movie;
  final double? width, height;
  const Poster(this.movie, {super.key, this.width, this.height});
  @override
  Widget build(BuildContext context) {
    final url = sid(movie['poster']);
    Widget image;
    if (url.startsWith('/posters/')) {
      image = SvgPicture.asset(
        'assets/posters/${url.split('/').last}',
        key: ValueKey(url),
        fit: BoxFit.cover,
      );
    } else if (url.startsWith('https://')) {
      // key theo địa chỉ ảnh: đổi phim thì tạo lại ảnh, tránh hiện nhầm poster cũ.
      image = Image.network(
        url,
        key: ValueKey(url),
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _fallback(),
      );
    } else {
      image = _fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: AspectRatio(aspectRatio: 2 / 3, child: image),
      ),
    );
  }

  Widget _fallback() => ColoredBox(
    color: ink,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          sid(movie['title']),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = ink});

  // Trên nền tối: đổi các màu chữ vốn dành cho nền sáng sang màu sáng hơn.
  static Color _onDark(Color c) {
    if (c == ink) return const Color(0xFFE6EBF0);
    if (c == muted) return const Color(0xFFAAB4BF);
    if (c == coral) return const Color(0xFFFF8573);
    if (c == const Color(0xFF28784B)) return const Color(0xFF6FD39B);
    if (c == const Color(0xFF2E7D32)) return const Color(0xFF6FD39B);
    if (c == const Color(0xFF427D5A)) return const Color(0xFF7FD6A4);
    if (c == const Color(0xFF9D7827)) return gold;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shade = dark ? _onDark(color) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: shade.withValues(alpha: dark ? .16 : .08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: shade,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  final String label, value;
  const InfoLine(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

class ResponsiveSplit extends StatelessWidget {
  final Widget left, right;
  final double rightWidth;
  const ResponsiveSplit({
    super.key,
    required this.left,
    required this.right,
    this.rightWidth = 340,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 850) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [left, const SizedBox(height: 24), right],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 28),
          SizedBox(width: rightWidth, child: right),
        ],
      );
    },
  );
}

Future<bool> confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;

class Steps extends StatelessWidget {
  final int current;
  const Steps(this.current, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Row(
      children: List.generate(
        4,
        (i) => Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: i <= current
                    ? coral
                    : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A3441)
                          : const Color(0xFFEDEBE5)),
                child: i < current
                    ? const Icon(Icons.check, size: 17, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          color: i <= current ? Colors.white : muted,
                        ),
                      ),
              ),
              const SizedBox(height: 7),
              Text(
                ['Suất chiếu', 'Chọn ghế', 'Thanh toán', 'Vé của bạn'][i],
                style: TextStyle(
                  fontSize: 12,
                  color: i <= current ? coral : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
