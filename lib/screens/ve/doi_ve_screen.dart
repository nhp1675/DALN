import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/dat_ve.dart';
import '../../models/rap.dart';
import '../../models/suat_chieu.dart';
import '../../providers/auth_provider.dart';
import '../../services/dat_ve_service.dart';
import '../../services/gia_ve_service.dart';
import '../../services/rap_service.dart';
import '../../services/suat_chieu_service.dart';
import '../../services/ve_service.dart';

/// UC-HDV — nhánh Đổi vé: chọn suất mới → chọn ghế trống → xử lý chênh lệch
class DoiVeScreen extends StatefulWidget {
  final Ve ve;
  const DoiVeScreen({super.key, required this.ve});
  @override
  State<DoiVeScreen> createState() => _DoiVeScreenState();
}

class _DoiVeScreenState extends State<DoiVeScreen> {
  final _suatService = SuatChieuService();
  final _rapService = RapService();
  final _datVe = DatVeService();
  final _giaVe = GiaVeService();
  final _veService = VeService();

  SuatChieu? _suatMoi;
  List<Ghe> _ghes = [];
  Ghe? _gheMoi;
  num? _giaMoi;
  bool _dangXuLy = false;
  String? _phimId;

  @override
  void initState() {
    super.initState();
    _taiPhimId();
  }

  Future<void> _taiPhimId() async {
    final suatCu = await _suatService.chiTiet(widget.ve.suatId);
    if (mounted) setState(() => _phimId = suatCu?.phimId);
  }

  Future<void> _chonSuat(SuatChieu s) async {
    setState(() {
      _suatMoi = s;
      _gheMoi = null;
      _giaMoi = null;
      _ghes = [];
    });
    final ghes = await _rapService.layGheCuaPhong(s.rapId, s.phongId);
    if (mounted) setState(() => _ghes = ghes);
  }

  Future<void> _chonGhe(Ghe g) async {
    final gia = await _giaVe.giaMotGhe(_suatMoi!, g);
    setState(() {
      _gheMoi = g;
      _giaMoi = gia;
    });
  }

  Future<void> _xacNhanDoi() async {
    setState(() => _dangXuLy = true);
    try {
      final uid = context.read<AuthProvider>().uid;
      final chenh = await _veService.doiVe(
        veCu: widget.ve,
        uid: uid,
        suatMoi: _suatMoi!,
        gheMoi: _gheMoi!,
        giaMoi: _giaMoi!,
      );
      if (mounted) {
        thongBao(context,
            chenh > 0
                ? 'Đổi vé thành công, đã thu thêm ${dinhDangTien(chenh)}.'
                : chenh < 0
                    ? 'Đổi vé thành công, hoàn lại ${dinhDangTien(-chenh)}.'
                    : 'Đổi vé thành công.');
        context.go('/ve');
      }
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi vé')),
      body: _phimId == null
          ? const Loading()
          : KhungWeb(
              max: 720,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Vé hiện tại', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${widget.ve.tenPhim} · Ghế ${widget.ve.tenGhe}'),
                      Text(
                          '${widget.ve.tenRap} · ${widget.ve.gioChieu == null ? '' : dinhDangNgayGio(widget.ve.gioChieu!)}',
                          style: const TextStyle(color: Colors.white54)),
                      Text('Giá đã thanh toán: ${dinhDangTien(widget.ve.giaVe)}'),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('1. Chọn suất chiếu mới', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<List<SuatChieu>>(
                  stream: _suatService.theoPhim(_phimId!),
                  builder: (context, s) {
                    final ds = (s.data ?? [])
                        .where((e) => e.conBanVe && e.suatId != widget.ve.suatId)
                        .toList();
                    if (ds.isEmpty) return const Rong('Không còn suất chiếu nào để đổi.');
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ds
                          .map((e) => ChoiceChip(
                                selected: _suatMoi?.suatId == e.suatId,
                                onSelected: (_) => _chonSuat(e),
                                label: Text('${dinhDangNgayGio(e.gioBatDau)} · ${e.tenRap}'),
                              ))
                          .toList(),
                    );
                  },
                ),
                if (_suatMoi != null) ...[
                  const SizedBox(height: 20),
                  const Text('2. Chọn ghế mới', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<Map<String, GheSuatChieu>>(
                    stream: _datVe.trangThaiGheTheoSuat(_suatMoi!.suatId),
                    builder: (context, snap) {
                      final tt = snap.data ?? {};
                      if (_ghes.isEmpty) return const Loading();
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _ghes.map((g) {
                          final trong = tt[g.gheId]?.conTrong ?? true;
                          final chon = _gheMoi?.gheId == g.gheId;
                          return ChoiceChip(
                            selected: chon,
                            onSelected: trong ? (_) => _chonGhe(g) : null,
                            label: Text(g.ten),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                if (_gheMoi != null && _giaMoi != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Giá vé mới: ${dinhDangTien(_giaMoi!)}'),
                        Text(
                          _giaMoi! > widget.ve.giaVe
                              ? 'Cần thanh toán thêm: ${dinhDangTien(_giaMoi! - widget.ve.giaVe)}'
                              : _giaMoi! < widget.ve.giaVe
                                  ? 'Được hoàn lại: ${dinhDangTien(widget.ve.giaVe - _giaMoi!)}'
                                  : 'Không phát sinh chênh lệch.',
                          style: const TextStyle(color: Colors.amberAccent),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _dangXuLy ? null : _xacNhanDoi,
                    child: _dangXuLy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Xác nhận đổi vé'),
                  ),
                ],
              ]),
            ),
    );
  }
}
