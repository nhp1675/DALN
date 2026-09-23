import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/widgets/common.dart';
import '../../models/phim.dart';
import '../../providers/auth_provider.dart';
import '../../services/phim_service.dart';

/// UC-XDSP (xem danh sách phim) + UC-TK (tìm kiếm)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = PhimService();
  final _tuKhoa = TextEditingController();
  String _trangThai = TrangThaiPhim.dangChieu;
  String? _theLoai;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          const Icon(Icons.local_movies, color: Color(0xFFE31C25)),
          const SizedBox(width: 8),
          const Text('CineTicket'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Rạp gần bạn',
            onPressed: () => context.push('/rap-gan-day'),
            icon: const Icon(Icons.place_outlined),
          ),
          if (auth.daDangNhap)
            IconButton(
              tooltip: 'Vé của tôi',
              onPressed: () => context.push('/ve'),
              icon: const Icon(Icons.confirmation_num_outlined),
            ),
          if (auth.laAdmin)
            IconButton(
              tooltip: 'Quản trị',
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          if (auth.daDangNhap)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (v) {
                if (v == 'out') auth.dangXuat();
              },
              itemBuilder: (c) => [
                PopupMenuItem(enabled: false, child: Text('Xin chào, ${auth.hoTen}')),
                const PopupMenuItem(value: 'out', child: Text('Đăng xuất')),
              ],
            )
          else
            TextButton(
              onPressed: () => context.push('/dang-nhap'),
              child: const Text('Đăng nhập'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: KhungWeb(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _tuKhoa,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Tìm phim theo tên, thể loại, đạo diễn...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: TrangThaiPhim.dangChieu, label: Text('Đang chiếu')),
                  ButtonSegment(value: TrangThaiPhim.sapChieu, label: Text('Sắp chiếu')),
                ],
                selected: {_trangThai},
                onSelectionChanged: (s) => setState(() => _trangThai = s.first),
              ),
            ]),
          ),
          Expanded(
            child: StreamBuilder<List<Phim>>(
              stream: _service.danhSach(trangThai: _trangThai),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Loading();
                if (snap.hasError) return Rong('Lỗi tải dữ liệu: ${snap.error}', icon: Icons.error_outline);
                final ds = _service.timKiem(snap.data ?? [], _tuKhoa.text, theLoai: _theLoai);
                if (ds.isEmpty) return const Rong('Không tìm thấy phim phù hợp.');
                return LayoutBuilder(builder: (context, c) {
                  final cot = (c.maxWidth / 220).floor().clamp(2, 6);
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cot,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: ds.length,
                    itemBuilder: (c, i) => _TheThuPhim(phim: ds[i]),
                  );
                });
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _TheThuPhim extends StatelessWidget {
  final Phim phim;
  const _TheThuPhim({required this.phim});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/phim/${phim.phimId}'),
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: phim.poster.isEmpty
                ? Container(
                    color: const Color(0xFF23262F),
                    child: const Center(child: Icon(Icons.movie_outlined, size: 40)))
                : CachedNetworkImage(
                    imageUrl: phim.poster,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (c, _, __) => const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(phim.tenPhim,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('${phim.theLoai.take(2).join(', ')} • ${phim.thoiLuong}\'',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}
