import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

enum LoginRole { student, faculty, admin }

extension on LoginRole {
  String get label {
    switch (this) {
      case LoginRole.student:
        return 'Student';
      case LoginRole.faculty:
        return 'Faculty';
      case LoginRole.admin:
        return 'Admin';
    }
  }

  String get value => label.toLowerCase();
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  LoginRole _selectedRole = LoginRole.student;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final UserModel? user = await context.read<AuthProvider>().login(
        email,
        password,
        roleHint: _selectedRole.value,
      );
      final actualRole = user?.role.trim().toLowerCase();

      if (actualRole != _selectedRole.value) {
        await context.read<AuthProvider>().logout();
        if (!mounted) return;
        setState(() {
          _errorMsg = 'This account is registered as ${actualRole?.isNotEmpty == true ? actualRole : 'an unknown role'}';
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = context.read<AuthProvider>().error ?? 'Login failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please contact the campus help desk to reset your password.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ClipPath(
            clipper: _TopHeroClipper(),
            child: Container(
              height: 340,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF7FBFF),
                    Color(0xFFDDEEEE),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 66,
            right: -22,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: const Color(0xFFBFE8E6).withOpacity(0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 220,
            left: -45,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.32),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth > 700 ? 560.0 : double.infinity;

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.account_balance_outlined,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Uniflow',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.display.copyWith(
                                    fontSize: 40,
                                    height: 1.0,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Unified Digital Campus Platform',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(34),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'LOGIN AS',
                                  style: AppTextStyles.micro.copyWith(
                                    color: const Color(0xFF353846),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E3E7),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: DropdownButtonFormField<LoginRole>(
                                    value: _selectedRole,
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF707484),
                                      size: 28,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFE0E3E7),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                                      ),
                                    ),
                                    dropdownColor: Colors.white,
                                    style: AppTextStyles.title.copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    items: LoginRole.values
                                        .map(
                                          (role) => DropdownMenuItem<LoginRole>(
                                            value: role,
                                            child: Text(role.label),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (role) {
                                      if (role == null) return;
                                      setState(() {
                                        _selectedRole = role;
                                        _errorMsg = null;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'EMAIL / USER ID',
                                  style: AppTextStyles.micro.copyWith(
                                    color: const Color(0xFF353846),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. bt21cse001@iiitn.ac.in',
                                    hintStyle: AppTextStyles.body.copyWith(
                                      color: const Color(0xFF9DA3B2),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFE0E3E7),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.alternate_email_rounded,
                                      color: Color(0xFF8A90A1),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  'PASSWORD',
                                  style: AppTextStyles.micro.copyWith(
                                    color: const Color(0xFF353846),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    if (!_isLoading) {
                                      _handleLogin();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    hintStyle: AppTextStyles.body.copyWith(
                                      color: const Color(0xFF9DA3B2),
                                      letterSpacing: 3,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFE0E3E7),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: const Color(0xFF7B8091),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPassword,
                                    child: Text(
                                      'Forgot Password?',
                                      style: AppTextStyles.body.copyWith(
                                        color: const Color(0xFF0E2D8A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: _errorMsg == null
                                      ? const SizedBox.shrink()
                                      : Container(
                                          key: ValueKey<String>(_errorMsg!),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _errorMsg!,
                                                  style: AppTextStyles.caption.copyWith(
                                                    color: AppColors.danger,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 58,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF153B99),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 10,
                                      shadowColor: const Color(0xFF153B99).withOpacity(0.25),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Login',
                                                style: AppTextStyles.subtitle.copyWith(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F7),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: const Color(0xFFD4D9E1)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF88E8E1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.shield_outlined,
                                          color: Color(0xFF0E6D66),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          'Secure academic access for students, faculty, and administrators.',
                                          style: AppTextStyles.body.copyWith(
                                            color: const Color(0xFF3C4252),
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Column(
                            children: [
                              Text(
                                'SECURE ACADEMIC ACCESS',
                                style: AppTextStyles.micro.copyWith(
                                  color: const Color(0xFF7A8090),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.7,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () {},
                                    child: Text(
                                      'Help Desk',
                                      style: AppTextStyles.body.copyWith(
                                        color: const Color(0xFF3F4658),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  TextButton(
                                    onPressed: () {},
                                    child: Text(
                                      'Privacy Policy',
                                      style: AppTextStyles.body.copyWith(
                                        color: const Color(0xFF3F4658),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopHeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.85);
    path.lineTo(size.width * 0.76, size.height);
    path.lineTo(size.width, size.height * 0.72);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
