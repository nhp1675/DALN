import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/common.dart';
import '../../providers/auth_provider.dart';

/// UC-LG-02: Đăng nhập
class DangNhapScreen extends StatefulWidget {
  const DangNhapScreen({super.key});
  @override
  State<DangNhapScreen> createState() => _DangNhapScreenState();
}

class _DangNhapScreenState extends State<DangNhapScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _matKhau = TextEditingController();
  bool _dangXuLy = false;
  bool _dangXuLyGoogle = false;
  bool _an = true;

  Future<void> _dangNhap() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _dangXuLy = true);
    try {
      await context.read<AuthProvider>().dangNhap(_email.text, _matKhau.text);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _dangNhapGoogle() async {
    setState(() => _dangXuLyGoogle = true);
    try {
      await context.read<AuthProvider>().dangNhapVoiGoogle();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    } finally {
      if (mounted) setState(() => _dangXuLyGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_movies, size: 56, color: Color(0xFFE31C25)),
                const SizedBox(height: 12),
                Text('CineTicket',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Đăng nhập để đặt vé', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _matKhau,
                  obscureText: _an,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_an ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _an = !_an),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
                  onFieldSubmitted: (_) => _dangNhap(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _dangXuLy ? null : _dangNhap,
                  child: _dangXuLy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Đăng nhập'),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('hoặc', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _dangXuLyGoogle ? null : _dangNhapGoogle,
                  icon: _dangXuLyGoogle
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Image.network(
                          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                          height: 18,
                          errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, size: 22),
                        ),
                  label: const Text('Đăng nhập với Google'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                TextButton(
                  onPressed: () => context.go('/dang-ky'),
                  child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                ),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Xem phim không cần đăng nhập'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}