// lib/features/auth/screens/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _obscurePass = true;

  // Hardcoded admin credentials — no backend needed
  static const String _adminEmail = 'admin@crisis.com';
  static const String _adminPassword = 'admin123';

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final enteredEmail = _emailCtrl.text.trim().toLowerCase();
    final enteredPass = _passCtrl.text;

    if (enteredEmail == _adminEmail && enteredPass == _adminPassword) {
      const expiry = '2099-01-01T00:00:00.000';
      await Future.wait([
        _storage.write(key: StorageKeys.accessToken, value: 'admin-token-456'),
        _storage.write(key: StorageKeys.userId, value: 'admin-001'),
        _storage.write(key: StorageKeys.userRole, value: 'admin'),
        _storage.write(key: StorageKeys.userName, value: 'Crisis Admin'),
        _storage.write(key: StorageKeys.sessionExpiry, value: expiry),
      ]);
      if (mounted) context.go(RouteNames.adminDashboard);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong email or password. Try admin@crisis.com / admin123'),
            backgroundColor: AppColors.critical,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(RouteNames.login)),
        title: const Text('Admin Access'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Security badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield, color: AppColors.accent, size: 16),
                      SizedBox(width: 8),
                      Text('SECURE ADMIN PORTAL', style: AppTextStyles.sectionHeader),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Text(
                  'Admin Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use: admin@crisis.com / admin123',
                  style: TextStyle(color: AppColors.accentGreen, fontSize: 13),
                ),

                const SizedBox(height: 40),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted),
                  ),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Valid email required',
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined,
                        color: AppColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 4 ? null : 'Password required',
                ),

                const SizedBox(height: 32),

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
                        : const Text('Sign In as Admin'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}