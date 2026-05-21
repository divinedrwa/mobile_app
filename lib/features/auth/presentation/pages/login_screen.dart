import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/security/secure_credentials_store.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_haptics.dart';
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
    _loadRememberMe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBiometricLoginUi();
      if (!mounted) return;
      // Only redirect if we're still on /login (avoid fighting with the
      // user tapping "Change" which navigates to /society-select).
      final loc = GoRouterState.of(context).matchedLocation;
      if (_selectedSocietyId.isEmpty && loc == '/login') {
        context.go('/society-select');
      }
    });
  }

  Future<void> _loadRememberMe() async {
    final remembered =
        StorageService.getBool(AppConstants.keyRememberMe) == true;
    if (!remembered) return;
    final creds = await SecureCredentialsStore.instance.readRememberMe();
    if (creds == null || !mounted) return;
    setState(() {
      _rememberMe = true;
      _usernameOrEmailController.text = creds.username;
      _passwordController.text = creds.password;
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
            content: Text(userFacingMessage(e, 'Login failed')),
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
      backgroundColor: DesignColors.background,
      body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!keyboardVisible) ...[
                      _buildLogo(),
                      const SizedBox(height: AppSpacing.lg),
                    ],

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

                    _buildLoginCard(),

                    const SizedBox(height: AppSpacing.lg),

                    _buildContactSupport(),

                    const SizedBox(height: AppSpacing.lg),
                  ],
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
        Image.asset(
          'assets/splash/gp_logo.png',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutCubic),
        const SizedBox(height: 10),
        const Text(
          'GatePass+',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ).animate().fadeIn(delay: DesignAnimations.sectionStaggerFor(1), duration: 500.ms),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.6,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: DesignAnimations.sectionStaggerFor(2), duration: 500.ms)
            .slideY(begin: DesignAnimations.slideNormal, end: 0),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Reside. Approve. Manage.',
          style: TextStyle(
            fontSize: 15,
            color: DesignColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: DesignAnimations.sectionStaggerFor(3), duration: 500.ms)
            .slideY(begin: DesignAnimations.slideNormal, end: 0),
      ],
    );
  }

  Widget _buildContactSupport() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Need help? ',
          style: TextStyle(
            fontSize: 13.5,
            color: DesignColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: _showContactSupportDialog,
          child: const Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: DesignColors.primary,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: DesignAnimations.sectionStaggerFor(5), duration: 500.ms);
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
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: DesignColors.background,
              borderRadius: DesignRadius.borderXL,
              border: Border.all(color: DesignColors.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DesignColors.primary.withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: DesignColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your society',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: DesignColors.textSecondary,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedSocietyId.isEmpty
                            ? 'None selected'
                            : (_societyDisplayLabel.isNotEmpty
                                ? _societyDisplayLabel
                                : _selectedSocietyId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: DesignColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (_selectedSocietyId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _selectedSocietyId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: DesignColors.textTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/society-select'),
                  style: TextButton.styleFrom(
                    foregroundColor: DesignColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
        .fadeIn(delay: DesignAnimations.sectionStaggerFor(4), duration: 600.ms)
        .slideY(begin: DesignAnimations.slideNormal, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _usernameOrEmailController,
      autofocus: false,
      textInputAction: TextInputAction.next,
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
          child: const Icon(Icons.person_outline, color: DesignColors.primary, size: 20),
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
          borderSide: const BorderSide(color: DesignColors.primary, width: 2),
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
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
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
          child: const Icon(Icons.lock_outline, color: DesignColors.primary, size: 20),
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
          borderSide: const BorderSide(color: DesignColors.primary, width: 2),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? false);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                activeColor: DesignColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Remember me',
              style: TextStyle(
                fontSize: 13.5,
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: _showForgotPasswordDialog,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: DesignColors.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return PolishedButton(
      text: 'Sign In',
      icon: Icons.arrow_forward_rounded,
      color: DesignColors.primary,
      onPressed: _isLoading || _selectedSocietyId.isEmpty
          ? null
          : _handleLogin,
      isLoading: _isLoading,
      isFullWidth: true,
    );
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
            password: _passwordController.text.trim(),
          );

      if (!mounted) return;

      if (success) {
        DesignHaptics.success();
        // Remember-me: persist or clear credentials in secure storage.
        if (_rememberMe) {
          await StorageService.setBool(AppConstants.keyRememberMe, true);
          await SecureCredentialsStore.instance.saveRememberMe(
            username: _usernameOrEmailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        } else {
          await StorageService.setBool(AppConstants.keyRememberMe, false);
          await SecureCredentialsStore.instance.clearRememberMe();
        }

        if (StorageService.getBool(AppConstants.keyBiometricLoginEnabled) ==
            true) {
          await SecureCredentialsStore.instance.saveCredentials(
            username: _usernameOrEmailController.text.trim(),
            password: _passwordController.text.trim(),
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
        DesignHaptics.error();
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
      DesignHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingMessage(e, 'Login failed')),
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
              child: const Icon(Icons.lock_reset, color: DesignColors.primary),
            ),
            const SizedBox(width: 12),
            const Text(
              'Reset Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Please contact your society admin to reset your password.',
          style: TextStyle(
            color: DesignColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
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
                color: DesignColors.info.withValues(alpha: 0.1),
                borderRadius: DesignRadius.borderLG,
              ),
              child: const Icon(Icons.support_agent, color: DesignColors.info),
            ),
            const SizedBox(width: 12),
            const Text(
              'Contact Support',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Having trouble logging in?',
              style: TextStyle(
                color: DesignColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Reach out to your society admin or management office for assistance with login issues, account activation, or general queries.',
              style: TextStyle(
                color: DesignColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
