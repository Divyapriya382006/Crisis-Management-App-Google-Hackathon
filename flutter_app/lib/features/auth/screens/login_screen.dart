import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _obscurePass = true;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const String _responderEmail = 'responder@crisis.com';
  static const String _responderPassword = 'respond123';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final enteredEmail = _emailCtrl.text.trim().toLowerCase();
    final enteredPass = _passCtrl.text;

    if (enteredEmail == _responderEmail && enteredPass == _responderPassword) {
      const expiry = '2099-01-01T00:00:00.000';
      await Future.wait([
        _storage.write(key: StorageKeys.accessToken, value: 'responder-token-123'),
        _storage.write(key: StorageKeys.userId, value: 'responder-001'),
        _storage.write(key: StorageKeys.userRole, value: 'responder'),
        _storage.write(key: StorageKeys.userName, value: 'Crisis Responder'),
        _storage.write(key: StorageKeys.sessionExpiry, value: expiry),
      ]);
      if (mounted) context.go(RouteNames.responderDashboard);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong credentials. Try responder@crisis.com / respond123'),
            backgroundColor: AppColors.critical,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height
        - MediaQuery.of(context).padding.top
        - MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF060E1E), Color(0xFF0A1628), Color(0xFF0F1E35)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Grid overlay
          CustomPaint(painter: _GridPainter(), size: Size.infinite),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                height: screenHeight,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),

                      // Back to home
                      GestureDetector(
                        onTap: () => context.go(RouteNames.home),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios, color: AppColors.textMuted, size: 14),
                            SizedBox(width: 4),
                            Text('Back', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Logo
                      ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accent, width: 1.5),
                          ),
                          child: const Icon(Icons.emergency, color: AppColors.accent, size: 36),
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'Staff Login',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -1.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MVP DEMO ACCESS',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Email: responder@crisis.com',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            ),
                            Text(
                              'Pass: respond123',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Email field
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Staff Email',
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted),
                        ),
                        validator: (v) =>
                            v != null && v.contains('@') ? null : 'Valid email required',
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textMuted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) =>
                            v != null && v.length >= 4 ? null : 'Password required',
                      ),

                      const Spacer(),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign In as Responder'),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Admin login link
                      Center(
                        child: TextButton(
                          onPressed: () => context.go(RouteNames.adminLogin),
                          child: const Text(
                            'Admin Login',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A2F4E).withOpacity(0.4)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}