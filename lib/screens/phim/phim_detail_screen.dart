import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/phim.dart';
import '../../models/rap.dart';
import '../../models/suat_chieu.dart';
import '../../providers/auth_provider.dart';
import '../../services/phim_service.dart';
import '../../services/rap_service.dart';
import '../../services/suat_chieu_service.dart';

/// UC-XTTP (thông tin phim) + UC-XLC (lịch chiếu) + UC-CR (chọn rạp) + UC-CSC
class PhimDetailScreen extends StatefulWidget {
  final String phimId;
  const PhimDetailScreen({super.key, required this.phimId});
  @override
  State<PhimDetailScreen> createState() => _PhimDetailScreenState();
}

class _PhimDetailScreenState extends State<PhimDetailScreen> {
  final _phimService = PhimService();
  final _rapService = RapService();
  final _suatService = SuatChieuService();

  String? _rapId;
  DateTime _ngay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin phim')),
      body: StreamBuilder<Phim?>(
        stream: _phimService.chiTiet(widget.phimId),
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          final phim = snap.data!;
          return KhungWeb(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              _ThongTinPhim(phim: phim),
              const SizedBox(height: 24),
              Text('Lịch chiếu', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _ChonNgay(ngay: _ngay, onChon: (d) => setState(() => _ngay = d)),
              const SizedBox(height: 12),
              StreamBuilder<List<Rap>>(
                stream: _rapService.danhSachRap(),
                builder: (context, rapSnap) {
                  final raps = (rapSnap.data ?? []).where((r) => r.dangHoatDong).toList();
                  return Wrap(spacing: 8, children: [
                    ChoiceChip(
                      label: const Text('Tất cả rạp'),
                      selected: _rapId == null,
                      onSelected: (_) => setState(() => _rapId = null),
                    ),
                    for (final r in raps)
                      ChoiceChip(
                        label: Text(r.tenRap),
                        selected: _rapId == r.rapId,
                        onSelected: (_) => setState(() => _rapId = r.rapId),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<SuatChieu>>(
                stream: _suatService.theoPhim(widget.phimId, rapId: _rapId, ngay: _ngay),
                builder: (context, s) {
                  if (s.connectionState == ConnectionState.waiting) return const Loading();
                  if (s.hasError) {
                    return Rong('Lỗi tải lịch chiếu: ${s.error}', icon: Icons.error_outline);
                  }
                  final ds = (s.data ?? []).where((e) => e.conBanVe).toList();
                  if (ds.isEmpty) {
                    return const Rong('Không có suất chiếu phù hợp trong ngày này.',
                        icon: Icons.event_busy_outlined);
                  }
                  final theoRap = <String, List<SuatChieu>>{};
                  for (final e in ds) {
                    theoRap.putIfAbsent(e.tenRap.isEmpty ? 'Rạp' : e.tenRap, () => []).add(e);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: theoRap.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: e.value
                                      .map((su) => OutlinedButton(
                                            onPressed: () => _chonSuat(su),
                                            child: Text(
                                                '${dinhDangGio(su.gioBatDau)} · ${su.tenPhong}'),
                                          ))
                                      .toList(),
                                ),
                              ]),
                            ))
                        .toList(),
                  );
                },
              ),
            ]),
          );
        },
      ),
    );
  }

  void _chonSuat(SuatChieu su) {
    // Tiền điều kiện UC-DV: khách hàng phải đăng nhập
    final auth = context.read<AuthProvider>();
    if (!auth.daDangNhap) {
      thongBao(context, 'Vui lòng đăng nhập để đặt vé.', loi: true);
      context.push('/dang-nhap');
      return;
    }
    context.push('/dat-ve/${su.suatId}');
  }
}

class _ThongTinPhim extends StatelessWidget {
  final Phim phim;
  const _ThongTinPhim({required this.phim});

  @override
  Widget build(BuildContext context) {
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 220,
        height: 320,
        child: phim.poster.isEmpty
            ? Container(color: const Color(0xFF23262F), child: const Icon(Icons.movie_outlined))
            : CachedNetworkImage(imageUrl: phim.poster, fit: BoxFit.cover),
      ),
    );
    final thongTin = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(phim.tenPhim, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        if (phim.doTuoi.isNotEmpty) Chip(label: Text(phim.doTuoi)),
        Chip(label: Text('${phim.thoiLuong} phút')),
        for (final t in phim.theLoai) Chip(label: Text(t)),
      ]),
      const SizedBox(height: 12),
      if (phim.daoDien.isNotEmpty) Text('Đạo diễn: ${phim.daoDien}'),
      if (phim.dienVien.isNotEmpty) Text('Diễn viên: ${phim.dienVien.join(', ')}'),
      const SizedBox(height: 12),
      Text(phim.noiDung, style: const TextStyle(color: Colors.white70, height: 1.5)),
    ]);

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 700) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: poster),
          const SizedBox(height: 16),
          thongTin,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        poster,
        const SizedBox(width: 24),
        Expanded(child: thongTin),
      ]);
    });
  }
}

class _ChonNgay extends StatelessWidget {
  final DateTime ngay;
  final ValueChanged<DateTime> onChon;
  const _ChonNgay({required this.ngay, required this.onChon});

  @override
  Widget build(BuildContext context) {
    final homNay = DateTime.now();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final d = homNay.add(Duration(days: i));
          final chon = d.day == ngay.day && d.month == ngay.month;
          return ChoiceChip(
            selected: chon,
            onSelected: (_) => onChon(d),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(i == 0 ? 'Hôm nay' : 'T${d.weekday == 7 ? 'CN' : d.weekday + 1}'),
                Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          );
        },
      ),
    );
  }
}