import 'package:flutter/material.dart';

class Trailer extends StatelessWidget {
  final String url;
  final double maxWidth;
  const Trailer({super.key, required this.url, this.maxWidth = 400});
  @override
  Widget build(BuildContext context) => const Text(
    'Trình phát trailer hỗ trợ trên bản Web.',
    style: TextStyle(color: Color(0xFFB8C2CC)),
  );
}
