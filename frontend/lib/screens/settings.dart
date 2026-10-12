import 'package:flutter/material.dart';
import '../platform/browser.dart';
import '../widgets/common.dart';

final appearance = ValueNotifier<ThemeMode>(switch (readPreference(
  'cinego-theme',
)) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
});

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Heading('Cài đặt'),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giao diện',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: appearance,
              builder: (context, value, child) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in {
                    ThemeMode.light: 'Sáng',
                    ThemeMode.dark: 'Tối',
                    ThemeMode.system: 'Theo hệ thống',
                  }.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: value == e.key,
                      onSelected: (_) {
                        appearance.value = e.key;
                        savePreference('cinego-theme', e.key.name);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Theo hệ thống sẽ tự đổi theo giao diện của thiết bị. Lựa chọn được lưu trên trình duyệt này.',
            ),
          ],
        ),
      ),
    ],
  );
}
