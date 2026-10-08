import 'package:flutter/material.dart';
import '../core/api.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  final bool register;
  final String next;
  const AuthScreen({super.key, this.register = false, this.next = '/'});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController();
  bool busy = false, showPassword = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final session = AppScope.of(context);
    try {
      await session.authenticate({
        'email': email.text.trim(),
        'password': password.text,
        if (widget.register) ...{
          'name': name.text.trim(),
          'phone': phone.text.trim(),
        },
      }, register: widget.register);
      if (mounted) {
        final next =
            widget.next.startsWith('/') && !widget.next.startsWith('//')
            ? widget.next
            : '/';
        Navigator.of(context).pushReplacementNamed(next);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    width: 960,
    children: [
      const SizedBox(height: 22),
      ResponsiveSplit(
        rightWidth: 420,
        left: Panel(
          color: const Color(0xFFE9EEE4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CINEGO MEMBERS',
                style: TextStyle(letterSpacing: 2, color: muted, fontSize: 12),
              ),
              const SizedBox(height: 28),
              const Text(
                'Một tài khoản.\nNhiều trải nghiệm.',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lưu vé, tích điểm và trò chuyện cùng những người yêu điện ảnh.',
                style: TextStyle(color: muted, height: 1.7),
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: coral,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(width: 22),
                    Expanded(
                      child: Text(
                        'YOUR NEXT\nGREAT STORY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        right: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(
                widget.register ? 'Tạo tài khoản' : 'Rất vui được gặp bạn',
                eyebrow: 'CHÀO MỪNG ĐẾN CINEGO',
              ),
              ErrorNote(error),
              if (widget.register) ...[
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  maxLength: 80,
                  validator: (v) => (v ?? '').trim().length < 2
                      ? 'Nhập ít nhất 2 ký tự'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                    ? null
                    : 'Email không hợp lệ',
              ),
              const SizedBox(height: 20),
              if (widget.register) ...[
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại (không bắt buộc)',
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ||
                          RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v!)
                      ? null
                      : 'Số điện thoại không hợp lệ',
                ),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: password,
                obscureText: !showPassword,
                maxLength: 128,
                autofillHints: [
                  widget.register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  helperText: widget.register ? 'Tối thiểu 12 ký tự' : null,
                  suffixIcon: IconButton(
                    tooltip: showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                    icon: Icon(
                      showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) => (v ?? '').length < (widget.register ? 12 : 1)
                    ? 'Mật khẩu chưa đủ độ dài'
                    : null,
                onFieldSubmitted: (_) => busy ? null : submit(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Đang xử lý…'
                        : widget.register
                        ? 'Tạo tài khoản'
                        : 'Đăng nhập',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => go(
                  context,
                  '/${widget.register ? 'login' : 'register'}?next=${Uri.encodeComponent(widget.next)}',
                ),
                child: Text(
                  widget.register
                      ? 'Đã có tài khoản? Đăng nhập'
                      : 'Chưa có tài khoản? Đăng ký ngay',
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      oldPassword = TextEditingController(),
      password = TextEditingController();
  final profileForm = GlobalKey<FormState>(),
      passwordForm = GlobalKey<FormState>();
  bool initialized = false, busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final u = AppScope.of(context).user!;
      name.text = sid(u['name']);
      phone.text = sid(u['phone']);
      initialized = true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    oldPassword.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save(bool changePassword) async {
    if (!(changePassword ? passwordForm : profileForm).currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final s = AppScope.of(context);
    try {
      await s.api.request(
        '/auth/${changePassword ? 'password' : 'profile'}',
        method: changePassword ? 'POST' : 'PATCH',
        body: changePassword
            ? {'oldPassword': oldPassword.text, 'password': password.text}
            : {'name': name.text.trim(), 'phone': phone.text.trim()},
      );
      await s.refresh();
      if (mounted) {
        if (changePassword) {
          go(context, '/login');
        } else {
          notice(context, 'Đã cập nhật thông tin.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context), u = s.user!;
    return PageBody(
      children: [
        Heading('Xin chào, ${u['name']}', eyebrow: 'TÀI KHOẢN CINEGO'),
        Panel(
          color: ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.stars_outlined,
                color: Color(0xFFE7C88B),
                size: 36,
              ),
              const SizedBox(height: 14),
              Text(
                sid(u['name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${u['points'] ?? 0} điểm',
                style: const TextStyle(
                  color: Color(0xFFE7C88B),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sid(u['email']),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Text(
                '1 điểm / ${s.policy['pointsPerVnd'] ?? 10000} đ chi tiêu ròng. Hoàn tiền sẽ giảm chi tiêu tích điểm.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chưa có chương trình đổi điểm/ưu đãi được xác nhận.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        ErrorNote(error),
        ResponsiveSplit(
          rightWidth: 420,
          left: Panel(
            child: Form(
              key: profileForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Nhập ít nhất 2 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ||
                            RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v!)
                        ? null
                        : 'Số điện thoại không hợp lệ',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : () => save(false),
                    child: const Text('Lưu thay đổi'),
                  ),
                ],
              ),
            ),
          ),
          right: Panel(
            child: Form(
              key: passwordForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đổi mật khẩu',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: oldPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Nhập mật khẩu hiện tại' : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    maxLength: 128,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới',
                    ),
                    validator: (v) =>
                        (v ?? '').length < 12 ? 'Tối thiểu 12 ký tự' : null,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Đổi mật khẩu sẽ kết thúc tất cả phiên đăng nhập.',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : () => save(true),
                    child: const Text('Đổi mật khẩu'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
