import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/api.dart';
import '../core/session.dart';

const coral = Color(0xFFD93B28);
const ink = Color(0xFF243644);
const muted = Color(0xFF687582);

class AppScope extends InheritedNotifier<Session> {
  const AppScope({super.key, required Session session, required super.child})
    : super(notifier: session);
  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
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
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
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
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E5DF)),
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
                  color: Color(0xFF94604D),
                  letterSpacing: 1.8,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width < 600 ? 28 : 36,
                fontWeight: FontWeight.w800,
                color: ink,
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
        fit: BoxFit.cover,
      );
    } else if (url.startsWith('https://')) {
      image = Image.network(
        url,
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
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
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
                backgroundColor: i <= current ? coral : const Color(0xFFEDEBE5),
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
