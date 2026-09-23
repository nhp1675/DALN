import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';
import '../../services/vi_tri_service.dart';

/// UC-DVI — Tìm rạp gần vị trí hiện tại
class RapGanDayScreen extends StatefulWidget {
  const RapGanDayScreen({super.key});
  @override
  State<RapGanDayScreen> createState() => _RapGanDayScreenState();
}

class _RapGanDayScreenState extends State<RapGanDayScreen> {
  final _service = ViTriService();
  List<RapGanDay>? _ds;
  String? _loi;
  bool _dangTai = false;

  @override
  void initState() {
    super.initState();
    _tim();
  }

  Future<void> _tim() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await _service.timRapGan(banKinhKm: ViTriService.banKinhMacDinh);
      if (mounted) setState(() => _ds = ds);
    } catch (e) {
      if (mounted) setState(() => _loi = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rạp gần bạn'),
        actions: [IconButton(onPressed: _tim, icon: const Icon(Icons.refresh))],
      ),
      body: KhungWeb(
        max: 720,
        child: _dangTai
            ? const Loading()
            : _loi != null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Rong(_loi!, icon: Icons.location_off_outlined),
                    FilledButton(onPressed: _tim, child: const Text('Thử lại')),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ds?.length ?? 0,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      final r = _ds![i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(r.rap.tenRap),
                          subtitle: Text('${r.rap.diaChi}\n${r.rap.soDienThoai}'),
                          isThreeLine: true,
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${r.khoangCach.toStringAsFixed(1)} km',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await _service.moChiDuong(r.rap);
                                } catch (e) {
                                  if (context.mounted) {
                                    thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
                                  }
                                }
                              },
                              child: const Text('Chỉ đường'),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
