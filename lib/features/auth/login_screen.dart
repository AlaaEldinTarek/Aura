import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/preferences_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      await ref.read(authStateNotifierProvider.notifier).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(authStateNotifierProvider.notifier).signInWithGoogle();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (e, st) {
      if (mounted) {
        debugPrint('❌ [GOOGLE_LOGIN] Error: $e\n$st');
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(guestModeProvider.notifier).setGuest(true);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final isRTL = context.locale.languageCode == 'ar';
    final resetController = TextEditingController(text: _emailController.text.trim());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('auth_forgot_password'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRTL
                  ? 'سنرسل لك رابط إعادة تعيين كلمة المرور'
                  : 'We\'ll send you a password reset link',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,

              decoration: InputDecoration(
                hintText: isRTL ? 'البريد الإلكتروني' : 'Email address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isRTL ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(authStateNotifierProvider.notifier)
                    .sendPasswordResetEmail(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isRTL
                        ? 'تم إرسال رابط إعادة التعيين إلى $email'
                        : 'Reset link sent to $email'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(AppConstants.paddingMedium),
                  ));
                }
              } catch (e) {
                if (mounted) _showErrorSnackBar(e.toString());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
            child: Text(isRTL ? 'إرسال' : 'Send'),
          ),
        ],
      ),
    );
    resetController.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = context.locale.languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppConstants.paddingXLarge),

                    // Logo with animation
                    Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/images/logo-0.png',
                        width: isTablet ? 140 : 120,
                        height: isTablet ? 140 : 120,
                      ),
                    ).animate().fadeIn(duration: 500.ms).scale(
                          duration: 800.ms,
                          curve: Curves.elasticOut,
                        ),

                    const SizedBox(height: 12),

                    // App Name
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AppConstants.primaryColor,
                          Color(0xFF6B4CE6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Aura',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Roboto',
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            TextSpan(
                              text: ' | ',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w300,
                                    color: AppConstants.primaryColor,
                                  ),
                            ),
                            TextSpan(
                              text: 'هالة',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Cairo',
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                    const SizedBox(height: 8),

                    // Tagline - improved styling with letter spacing
                    Text(
                      'home_welcome'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark
                                ? AppConstants.darkTextSecondary
                                : AppConstants.lightTextSecondary,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                          begin: 0.2,
                          curve: Curves.easeOut,
                        ),

                    const SizedBox(height: 20),

                    // Login Card
                    _buildLoginCard(context, isRTL, isDark)
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 400.ms)
                        .slideY(begin: 0.1),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Social Login
                    _buildSocialLoginSection(context, isRTL, isDark)
                        .animate()
                        .fadeIn(delay: 500.ms, duration: 400.ms),

                    const SizedBox(height: AppConstants.paddingMedium),

                    // Guest Mode
                    _buildGuestModeButton(context)
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 400.ms),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Sign Up Link
                    _buildSignUpLink(context)
                        .animate()
                        .fadeIn(delay: 700.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, bool isRTL, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'auth_login'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingSmall),

          // Subtitle
          Text(
            'auth_login_with_email'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppConstants.darkTextSecondary
                      : AppConstants.lightTextSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'auth_email'.tr(),
              hintText: 'auth_email_hint'.tr(),
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: BorderSide(
                  color: isDark
                      ? AppConstants.darkBorder
                      : AppConstants.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: BorderSide(
                  color: isDark
                      ? AppConstants.darkBorder
                      : AppConstants.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: const BorderSide(
                    color: AppConstants.primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide:
                    const BorderSide(color: AppConstants.error, width: 1),
              ),
              filled: true,
              fillColor: isDark ? AppConstants.darkSurface : Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'auth_validation_email_required'.tr();
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'auth_validation_email_invalid'.tr();
              }
              return null;
            },
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signInWithEmail(),
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'auth_password'.tr(),
              hintText: 'auth_password_hint'.tr(),
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () async {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: BorderSide(
                  color: isDark
                      ? AppConstants.darkBorder
                      : AppConstants.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: BorderSide(
                  color: isDark
                      ? AppConstants.darkBorder
                      : AppConstants.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: const BorderSide(
                    color: AppConstants.primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide:
                    const BorderSide(color: AppConstants.error, width: 1),
              ),
              filled: true,
              fillColor: isDark ? AppConstants.darkSurface : Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'auth_validation_password_required'.tr();
              }
              if (value.length < AppConstants.minPasswordLength) {
                return 'auth_validation_password_short'.tr();
              }
              return null;
            },
          ),

          const SizedBox(height: AppConstants.paddingSmall),

          // Forgot Password (align based on RTL)
          Align(
            alignment: isRTL ? Alignment.centerLeft : Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _showForgotPasswordDialog,
              child: Text(
                'auth_forgot_password'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // Login Button
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signInWithEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'auth_login_button'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLoginSection(
      BuildContext context, bool isRTL, bool isDark) {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMedium),
              child: Text(
                'auth_or'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppConstants.darkTextSecondary
                          : AppConstants.lightTextSecondary,
                    ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppConstants.paddingMedium),

        // Google Sign-In Button (same as signup page)
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _signInWithGoogle,
            icon: const Icon(Icons.login, size: 18),
            label: Text('auth_login_with_google'.tr(), style: const TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppConstants.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              side:
                  BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestModeButton(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _continueAsGuest,
        icon: const Icon(Icons.person_outline, size: 18),
        label: Text('guest_mode'.tr(), style: const TextStyle(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.primaryColor,
          side: BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'auth_no_account'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () async {
                                if (mounted) {
                    Navigator.of(context).pushNamed('/signup');
                  }
                },
          child: Text(
            'auth_signup'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
