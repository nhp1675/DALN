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
      password = TextEditingController(),
      confirmPassword = TextEditingController(),
      code = TextEditingController();
  bool busy = false, showPassword = false, showConfirmPassword = false;
  bool verificationSent = false;
  String? challengeId;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    code.dispose();
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
      if (challengeId != null) {
        await session.verifyLogin(challengeId!, code.text.trim());
      } else {
        final result = await session.authenticate({
          'email': email.text.trim(),
          'password': password.text,
          if (widget.register) ...{
            'name': name.text.trim(),
            'phone': phone.text.trim(),
          },
        }, register: widget.register);
        if (mounted && result['verificationRequired'] == true) {
          setState(() => verificationSent = true);
          return;
        }
        if (mounted && result['mfaRequired'] == true) {
          setState(() => challengeId = sid(result['challengeId']));
          return;
        }
      }
      if (mounted) navigateAfterLogin();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void navigateAfterLogin() {
    final next = widget.next.startsWith('/') && !widget.next.startsWith('//')
        ? widget.next
        : '/';
    Navigator.of(context).pushReplacementNamed(next);
  }

  Future<void> resendVerification() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.of(context).resendVerification(email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nếu email chưa được xác minh, liên kết mới đã được gửi.',
            ),
          ),
        );
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
        left: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x33FFFFFF)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [night, Color(0xFF1F2B38)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thành viên CineGo',
                style: TextStyle(
                  color: gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Một tài khoản.\nNhiều trải nghiệm.',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lưu vé, tích điểm và trò chuyện cùng những người yêu điện ảnh.',
                style: TextStyle(color: Color(0xFFB8C2CC), height: 1.7),
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
                        'Câu chuyện\ntiếp theo của bạn',
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
                verificationSent
                    ? 'Kiểm tra email'
                    : challengeId != null
                    ? 'Xác thực đăng nhập'
                    : widget.register
                    ? 'Tạo tài khoản'
                    : 'Rất vui được gặp bạn',
                eyebrow: 'Chào mừng đến CineGo',
              ),
              ErrorNote(error),
              if (verificationSent) ...[
                Text(
                  'Tài khoản đã được tạo. Mở liên kết xác minh gửi đến ${email.text.trim()} để kích hoạt trước khi đăng nhập.',
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : resendVerification,
                    child: Text(
                      busy ? 'Đang gửi…' : 'Gửi lại liên kết xác minh',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => go(context, '/login'),
                  child: const Text('Đã xác minh? Đăng nhập'),
                ),
              ] else if (challengeId != null) ...[
                const Text(
                  'Nhập mã 6 chữ số vừa được gửi đến email của bạn. Mã có hiệu lực trong 10 phút.',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Mã xác thực'),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                      ? null
                      : 'Nhập mã gồm 6 chữ số',
                  onFieldSubmitted: (_) => busy ? null : submit(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'Đang xác thực…' : 'Xác nhận mã'),
                  ),
                ),
                TextButton(
                  onPressed: () => go(
                    context,
                    '/login?next=${Uri.encodeComponent(widget.next)}',
                  ),
                  child: const Text('Quay lại đăng nhập'),
                ),
              ] else ...[
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
                  validator: (v) =>
                      (v ?? '').length < (widget.register ? 12 : 1)
                      ? 'Mật khẩu chưa đủ độ dài'
                      : null,
                  onFieldSubmitted: (_) => busy ? null : submit(),
                ),
                if (widget.register) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: !showConfirmPassword,
                    maxLength: 128,
                    decoration: InputDecoration(
                      labelText: 'Nhập lại mật khẩu',
                      suffixIcon: IconButton(
                        tooltip: showConfirmPassword
                            ? 'Ẩn mật khẩu'
                            : 'Hiện mật khẩu',
                        onPressed: () => setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        ),
                        icon: Icon(
                          showConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) => v != password.text
                        ? 'Mật khẩu nhập lại không khớp'
                        : null,
                    onFieldSubmitted: (_) => busy ? null : submit(),
                  ),
                ],
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
                if (!widget.register) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => go(context, '/forgot-password'),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
    ],
  );
}

class VerifyEmailScreen extends StatefulWidget {
  final String token;
  const VerifyEmailScreen({super.key, required this.token});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmailScreen> {
  final email = TextEditingController();
  bool loading = true, verified = false, started = false;
  bool resendBusy = false, resendSent = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    verify();
  }

  Future<void> verify() async {
    try {
      if (widget.token.isEmpty) {
        throw Exception('Liên kết xác minh không hợp lệ.');
      }
      await AppScope.of(context).verifyEmail(widget.token);
      if (mounted) setState(() => verified = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resendVerification() async {
    setState(() {
      resendBusy = true;
      error = null;
      resendSent = false;
    });
    try {
      await AppScope.of(context).resendVerification(email.text.trim());
      if (mounted) setState(() => resendSent = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => resendBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    width: 520,
    children: [
      const SizedBox(height: 36),
      Heading('Xác minh email', eyebrow: 'Tài khoản CineGo'),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else if (verified) ...[
        const Text(
          'Email đã được xác minh. Tài khoản của bạn đã được kích hoạt.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => go(context, '/login'),
          child: const Text('Đăng nhập'),
        ),
      ] else ...[
        ErrorNote(error),
        const Text(
          'Nếu liên kết đã hết hạn, nhập email để yêu cầu gửi liên kết xác minh mới.',
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: resendBusy ? null : resendVerification,
          child: Text(resendBusy ? 'Đang gửi…' : 'Gửi lại liên kết xác minh'),
        ),
        if (resendSent)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Nếu email cần xác minh, liên kết mới đã được gửi.'),
          ),
        TextButton(
          onPressed: () => go(context, '/login'),
          child: const Text('Về trang đăng nhập'),
        ),
      ],
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
      password = TextEditingController(),
      confirmPassword = TextEditingController();
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
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> save(bool changePassword) async {
    if (!(changePassword ? passwordForm : profileForm).currentState!
        .validate()) {
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
        Heading('Xin chào, ${u['name']}', eyebrow: 'Tài khoản CineGo'),
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
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: true,
                    maxLength: 128,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu mới',
                    ),
                    validator: (v) => v == password.text
                        ? null
                        : 'Mật khẩu nhập lại chưa khớp',
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPasswordScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  bool busy = false, sent = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.of(context).api.request(
        '/auth/forgot-password',
        method: 'POST',
        body: {'email': email.text.trim()},
      );
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    width: 480,
    children: [
      const SizedBox(height: 22),
      const Heading('Quên mật khẩu', eyebrow: 'Lấy lại quyền truy cập'),
      if (sent)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 40,
                color: coral,
              ),
              const SizedBox(height: 14),
              Text(
                'Nếu ${email.text.trim()} đã đăng ký tại CineGo, chúng tôi vừa gửi một liên kết đặt lại mật khẩu. Liên kết có hiệu lực trong 30 phút. Hãy kiểm tra cả hộp thư rác.',
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => go(context, '/login'),
                child: const Text('Quay lại đăng nhập'),
              ),
            ],
          ),
        )
      else
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập email đã đăng ký, chúng tôi sẽ gửi liên kết để bạn đặt mật khẩu mới.',
                style: TextStyle(color: muted, height: 1.6),
              ),
              const SizedBox(height: 20),
              ErrorNote(error),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                    ? null
                    : 'Email không hợp lệ',
                onFieldSubmitted: (_) => busy ? null : submit(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Đang gửi…' : 'Gửi liên kết đặt lại'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => go(context, '/login'),
                child: const Text('Quay lại đăng nhập'),
              ),
            ],
          ),
        ),
    ],
  );
}

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPasswordScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      confirmPassword = TextEditingController();
  bool busy = false, showPassword = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.of(context).api.request(
        '/auth/reset-password',
        method: 'POST',
        body: {'token': widget.token, 'password': password.text},
      );
      if (mounted) {
        notice(
          context,
          'Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới.',
        );
        go(context, '/login');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    width: 480,
    children: [
      const SizedBox(height: 22),
      const Heading('Đặt mật khẩu mới', eyebrow: 'Lấy lại quyền truy cập'),
      if (widget.token.isEmpty)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Liên kết đặt lại mật khẩu không hợp lệ.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => go(context, '/forgot-password'),
                child: const Text('Gửi lại liên kết'),
              ),
            ],
          ),
        )
      else
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ErrorNote(error),
              TextFormField(
                controller: password,
                obscureText: !showPassword,
                maxLength: 128,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  helperText: 'Tối thiểu 12 ký tự',
                  suffixIcon: IconButton(
                    tooltip: showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                    icon: Icon(
                      showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').length < 12 ? 'Tối thiểu 12 ký tự' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: confirmPassword,
                obscureText: !showPassword,
                maxLength: 128,
                decoration: const InputDecoration(
                  labelText: 'Nhập lại mật khẩu mới',
                ),
                validator: (v) =>
                    v == password.text ? null : 'Mật khẩu nhập lại chưa khớp',
                onFieldSubmitted: (_) => busy ? null : submit(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Đang lưu…' : 'Đặt lại mật khẩu'),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
