import 'package:flutter/material.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class Rong extends StatelessWidget {
  final String text;
  final IconData icon;
  const Rong(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54)),
          ]),
        ),
      );
}

void thongBao(BuildContext context, String msg, {bool loi = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: loi ? Colors.red.shade700 : null,
    ));
}

/// Giới hạn chiều rộng nội dung trên web (NFR #11 Responsive)
class KhungWeb extends StatelessWidget {
  final Widget child;
  final double max;
  const KhungWeb({super.key, required this.child, this.max = 1100});
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child));
}
