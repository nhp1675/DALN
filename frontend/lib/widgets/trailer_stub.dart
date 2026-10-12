import 'package:flutter/material.dart';

class Trailer extends StatelessWidget {
  final String url;
  const Trailer({super.key, required this.url});
  @override
  Widget build(BuildContext context) =>
      const Text('Trình phát trailer hỗ trợ trên bản Web.');
}
