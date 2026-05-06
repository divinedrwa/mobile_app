import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/secure_credentials_store.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/widgets/polished_button.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Ultra-Professional Login Screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _showBiometricLogin = false;

  String _selectedSocietyId = '';
  String _societyDisplayLabel = '';

  void _syncSocietyFromStorage() {
    final sid = StorageService.getPreferredLoginSocietyId()?.trim() ?? '';
    final name = StorageService.getPreferredLoginSocietyName()?.trim() ?? '';
    setState(() {
      _selectedSocietyId = sid;
      _societyDisplayLabel =
          name.isNotEmpty ? name : (sid.isNotEmpty ? sid : '');
    });
  }

  @override
  void initState() {
    super.initState();
    _syncSocietyFromStorage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBiometricLoginUi();
      if (!mounted) return;
      if (_selectedSocietyId.isEmpty) {
        context.go('/society-select');
      }
    });
  }

  Future<void> _refreshBiometricLoginUi() async {
    final want =
        StorageService.getBool(AppConstants.keyBiometricLoginEnabled) == true;
    final has = await SecureCredentialsStore.instance.hasCredentials();
    final deviceOk = await BiometricAuthService().deviceCanUseBiometric();
    final show = want && has && deviceOk;
    if (mounted) setState(() => _showBiometricLogin = show);
  }

  Future<void> _loginWithBiometric() async {
    final ok = await BiometricAuthService().authenticate(
      localizedReason: 'Sign in to ${AppConstants.appName}',
    );
    if (!ok || !mounted) return;
    final creds = await SecureCredentialsStore.instance.readCredentials();
    if (creds == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with your password once to set up biometrics.'),
        ),
      );
      await _refreshBiometricLoginUi();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authProvider.notifier).login(
            societyId: creds.societyId,
            username: creds.username,
            password: creds.password,
          );
      if (!mounted) return;
      if (success) {
        final user = ref.read(authProvider).user;
        if (user != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.name}!'),
              backgroundColor: DesignColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await SecureCredentialsStore.instance.clearCredentials();
        await _refreshBiometricLoginUi();
        if (!mounted) return;
        final errorMessage =
            ref.read(authProvider).errorMessage ?? 'Login failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: DesignColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: DesignColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              DesignColors.primary.withValues(alpha: 0.05),
              Colors.white,
              DesignColors.primaryLight.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Section
                    if (!keyboardVisible) ...[
                      _buildLogo(),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // Welcome Text
                    _buildWelcomeText(),
                    if (_showBiometricLogin && !_isLoading) ...[
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: _loginWithBiometric,
                        icon: const Icon(Icons.fingerprint, size: 22),
                        label: const Text('Sign in with biometrics'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DesignColors.primary,
                          side: BorderSide(color: DesignColors.primary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),

                    // Login Card
                    _buildLoginCard(),

                    const SizedBox(height: AppSpacing.lg),

                    // Forgot Password
                    _buildForgotPassword(),

                    const SizedBox(height: AppSpacing.xl),

                    // Sign Up Link
                    _buildSignUpLink(),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(DesignSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesignColors.primary, DesignColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: DesignColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.home_rounded,
            size: 60,
            color: Colors.white,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.md),
        Text(
          'DIVINE APP',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: DesignColors.primary,
            letterSpacing: 2,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome Back',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms)
            .slideY(begin: 0.3, end: 0),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sign in to access your society dashboard',
          style: TextStyle(
            fontSize: 16,
            color: DesignColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 600.ms)
            .slideY(begin: 0.3, end: 0),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DesignRadius.borderXXL,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignSpacing.lg),
            decoration: BoxDecoration(
              color: DesignColors.background,
              borderRadius: DesignRadius.borderXL,
              border: Border.all(color: DesignColors.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.apartment_rounded, color: DesignColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your society',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DesignColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedSocietyId.isEmpty
                            ? 'None selected'
                            : (_societyDisplayLabel.isNotEmpty
                                ? _societyDisplayLabel
                                : _selectedSocietyId),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_selectedSocietyId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _selectedSocietyId,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: DesignColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/society-select'),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Email Field
          _buildEmailField(),
          const SizedBox(height: AppSpacing.lg),

          // Password Field
          _buildPasswordField(),
          const SizedBox(height: AppSpacing.md),

          // Remember Me
          _buildRememberMe(),
          const SizedBox(height: AppSpacing.xl),

          // Login Button
          _buildLoginButton(),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 600.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _usernameOrEmailController,
      keyboardType: TextInputType.text,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Username or Email',
        hintText: 'Enter your username or email',
        prefixIcon: Container(
          margin: const EdgeInsets.all(DesignSpacing.md),
          padding: const EdgeInsets.all(DesignSpacing.sm),
          decoration: BoxDecoration(
            color: DesignColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.person_outline, color: DesignColors.primary, size: 20),
        ),
        filled: true,
        fillColor: DesignColors.background,
        border: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: const BorderSide(color: DesignColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: BorderSide(color: DesignColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: const BorderSide(color: DesignColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: const BorderSide(color: DesignColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your username or email';
        }
        if (value.length < 3) {
          return 'Must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: Container(
          margin: const EdgeInsets.all(DesignSpacing.md),
          padding: const EdgeInsets.all(DesignSpacing.sm),
          decoration: BoxDecoration(
            color: DesignColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.lock_outline, color: DesignColors.primary, size: 20),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: DesignColors.textSecondary,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        filled: true,
        fillColor: DesignColors.background,
        border: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: const BorderSide(color: DesignColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: BorderSide(color: DesignColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: const BorderSide(color: DesignColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DesignRadius.borderXL,
          borderSide: const BorderSide(color: DesignColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() => _rememberMe = value ?? false);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            activeColor: DesignColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Remember me',
          style: TextStyle(
            fontSize: 14,
            color: DesignColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return PolishedButton(
      text: 'Sign In',
      icon: Icons.arrow_forward_rounded,
      onPressed: _isLoading || _selectedSocietyId.isEmpty
          ? null
          : _handleLogin,
      isLoading: _isLoading,
      isFullWidth: true,
    );
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: () {
        _showForgotPasswordDialog();
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      child: Text(
        'Forgot Password?',
        style: TextStyle(
          color: DesignColors.primary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: DesignColors.textSecondary,
            fontSize: 15,
          ),
        ),
        TextButton(
          onPressed: () => context.push('/invite-register'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            'Join with invite',
            style: TextStyle(
              color: DesignColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 900.ms);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(authProvider.notifier).login(
            societyId: _selectedSocietyId,
            username: _usernameOrEmailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      if (success) {
        if (StorageService.getBool(AppConstants.keyBiometricLoginEnabled) ==
            true) {
          await SecureCredentialsStore.instance.saveCredentials(
            username: _usernameOrEmailController.text.trim(),
            password: _passwordController.text,
            societyId: _selectedSocietyId,
          );
        }
        await _refreshBiometricLoginUi();
        // GoRouter redirect (via ref.listen in DivineApp) handles navigation
        // automatically when auth state changes. No explicit context.go needed.
        final user = ref.read(authProvider).user;
        if (user != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.name}!'),
              backgroundColor: DesignColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show error from auth provider
        final errorMessage = ref.read(authProvider).errorMessage ?? 'Login failed';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: DesignColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: DesignColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: DesignRadius.borderXL,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.1),
                borderRadius: DesignRadius.borderLG,
              ),
              child: Icon(Icons.lock_reset, color: DesignColors.primary),
            ),
            const SizedBox(width: 12),
            const Text(
              'Reset Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(
                color: DesignColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.email_outlined, color: DesignColors.primary),
                filled: true,
                fillColor: DesignColors.background,
                border: OutlineInputBorder(
                  borderRadius: DesignRadius.borderLG,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: DesignRadius.borderLG,
                  borderSide: BorderSide(color: DesignColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: DesignColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset link sent to your email!'),
                    backgroundColor: DesignColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: DesignRadius.borderLG,
              ),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }
}
