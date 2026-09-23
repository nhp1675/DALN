import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/common.dart';
import '../../providers/auth_provider.dart';

/// UC-SI-01: Đăng ký
class DangKyScreen extends StatefulWidget {
  const DangKyScreen({super.key});
  @override
  State<DangKyScreen> createState() => _DangKyScreenState();
}

class _DangKyScreenState extends State<DangKyScreen> {
  final _form = GlobalKey<FormState>();
  final _hoTen = TextEditingController();
  final _email = TextEditingController();
  final _sdt = TextEditingController();
  final _matKhau = TextEditingController();
  final _nhapLai = TextEditingController();
  bool _dangXuLy = false;

  Future<void> _dangKy() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _dangXuLy = true);
    try {
      await context.read<AuthProvider>().dangKy(
            hoTen: _hoTen.text,
            email: _email.text,
            soDienThoai: _sdt.text,
            matKhau: _matKhau.text,
          );
      if (mounted) {
        thongBao(context, 'Đăng ký thành công!');
        context.go('/');
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
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _hoTen,
                  decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Vui lòng nhập họ tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sdt,
                  decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().length < 9) ? 'Số điện thoại không hợp lệ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _matKhau,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu tối thiểu 6 ký tự' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nhapLai,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset)),
                  validator: (v) => v != _matKhau.text ? 'Mật khẩu nhập lại không khớp' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _dangXuLy ? null : _dangKy,
                  child: _dangXuLy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Đăng ký'),
                ),
                TextButton(
                  onPressed: () => context.go('/dang-nhap'),
                  child: const Text('Đã có tài khoản? Đăng nhập'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
