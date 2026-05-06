import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/storage_service.dart';
import '../providers/auth_provider.dart';

/// DIVINE APP - LOGIN SCREEN
/// Following the exact design specification with centralized design tokens
/// 
/// This is an example implementation showing how to use design_tokens.dart
/// to create a professional, spec-compliant login screen.

class LoginScreenNew extends ConsumerStatefulWidget {
  const LoginScreenNew({super.key});

  @override
  ConsumerState<LoginScreenNew> createState() => _LoginScreenNewState();
}

class _LoginScreenNewState extends ConsumerState<LoginScreenNew> {
  final _societyIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final saved = StorageService.getPreferredLoginSocietyId();
    if (saved != null && saved.isNotEmpty) {
      _societyIdController.text = saved;
    }
  }

  @override
  void dispose() {
    _societyIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final sid = _societyIdController.text.trim();
      if (sid.isEmpty) {
        _showError('Enter society id');
        return;
      }
      final success = await ref.read(authProvider.notifier).login(
            societyId: sid,
            username: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      if (success) {
        await StorageService.savePreferredLoginSocietyId(sid);
        // GoRouter redirect (via ref.listen in DivineApp) handles navigation
        // automatically when auth state changes. No explicit context.go needed.
      } else {
        _showError(ref.read(authProvider).errorMessage ?? 'Login failed');
      }
    } catch (e) {
      _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: DesignColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: DesignRadius.borderMD,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(DesignSpacing.screenPaddingH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: DesignSpacing.xxxl),
                
                // Logo
                _buildLogo(),
                
                SizedBox(height: DesignSpacing.xxl),
                
                // Welcome Text
                _buildWelcomeText(),
                
                SizedBox(height: DesignSpacing.xl),
                
                // Society (tenant login requires society scope)
                _buildSocietyIdField(),
                
                SizedBox(height: DesignSpacing.lg),
                
                // Email Field
                _buildEmailField(),
                
                SizedBox(height: DesignSpacing.lg),
                
                // Password Field
                _buildPasswordField(),
                
                SizedBox(height: DesignSpacing.md),
                
                // Remember Me & Forgot Password
                _buildRememberMeRow(),
                
                SizedBox(height: DesignSpacing.xl),
                
                // Sign In Button
                _buildSignInButton(),
                
                SizedBox(height: DesignSpacing.xl),
                
                // Divider with OR
                _buildDivider(),
                
                SizedBox(height: DesignSpacing.xl),
                
                // Social Login Buttons
                _buildSocialButtons(),
                
                SizedBox(height: DesignSpacing.xl),
                
                // Sign Up Link
                _buildSignUpLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Logo Section
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: DesignColors.primary,
            borderRadius: DesignRadius.borderXL,
            boxShadow: DesignElevation.md,
          ),
          child: Icon(
            Icons.home_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        SizedBox(height: DesignSpacing.md),
        Text(
          'DIVINE APP',
          style: DesignTypography.labelSmall.copyWith(
            color: DesignColors.primary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Welcome Text
  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome Back',
          style: DesignTypography.headingXL,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: DesignSpacing.xs),
        Text(
          'Sign in to access your society dashboard',
          style: DesignTypography.body.copyWith(
            color: DesignColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Society id (`cuid`) — same society as your account on the server.
  Widget _buildSocietyIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Society id', style: DesignTypography.label),
        SizedBox(height: DesignSpacing.xs),
        TextFormField(
          controller: _societyIdController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'e.g. default-society',
            border: OutlineInputBorder(borderRadius: DesignRadius.borderMD),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Society id is required' : null,
        ),
      ],
    );
  }

  /// Email Input Field
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: DesignTypography.label,
        ),
        SizedBox(height: DesignSpacing.xs),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: DesignComponents.inputDecoration(
            hint: 'Enter your email',
            prefixIcon: Icon(
              Icons.email_outlined,
              size: 20,
              color: DesignColors.textTertiary,
            ),
          ),
          style: DesignTypography.body,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Password Input Field
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: DesignTypography.label,
        ),
        SizedBox(height: DesignSpacing.xs),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: DesignComponents.inputDecoration(
            hint: 'Enter your password',
            prefixIcon: Icon(
              Icons.lock_outline,
              size: 20,
              color: DesignColors.textTertiary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: DesignColors.textTertiary,
              ),
              onPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
          ),
          style: DesignTypography.body,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Remember Me & Forgot Password Row
  Widget _buildRememberMeRow() {
    return Row(
      children: [
        // Remember Me Checkbox
        InkWell(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          borderRadius: DesignRadius.borderSM,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _rememberMe ? DesignColors.primary : Colors.transparent,
                  border: Border.all(
                    color: _rememberMe ? DesignColors.primary : DesignColors.border,
                    width: 2,
                  ),
                  borderRadius: DesignRadius.borderXS,
                ),
                child: _rememberMe
                    ? Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              SizedBox(width: DesignSpacing.sm),
              Text(
                'Remember me',
                style: DesignTypography.bodySmall,
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Forgot Password Link
        InkWell(
          onTap: () {
            // Navigate to forgot password
          },
          borderRadius: DesignRadius.borderSM,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DesignSpacing.sm,
              vertical: DesignSpacing.xs,
            ),
            child: Text(
              'Forgot Password?',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sign In Button
  Widget _buildSignInButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: DesignComponents.primaryButtonStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return DesignColors.surfaceSoft;
            }
            return DesignColors.primary;
          }),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: DesignTypography.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: DesignSpacing.sm),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
      ),
    );
  }

  /// Divider with OR Text
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: DesignColors.divider,
            thickness: 1,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignSpacing.md),
          child: Text(
            'OR',
            style: DesignTypography.caption.copyWith(
              color: DesignColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: DesignColors.divider,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  /// Social Login Buttons
  Widget _buildSocialButtons() {
    return Column(
      children: [
        // Google Button
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              // Handle Google login
            },
            style: DesignComponents.googleButtonStyle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.g_mobiledata,
                  size: 24,
                  color: DesignColors.google,
                ),
                SizedBox(width: DesignSpacing.sm),
                Text(
                  'Google',
                  style: DesignTypography.button.copyWith(
                    color: DesignColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        SizedBox(height: DesignSpacing.md),
        
        // Apple Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              // Handle Apple login
            },
            style: DesignComponents.appleButtonStyle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apple, size: 24),
                SizedBox(width: DesignSpacing.sm),
                Text(
                  'Apple',
                  style: DesignTypography.button,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Sign Up Link
  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: DesignTypography.bodySmall,
        ),
        InkWell(
          onTap: () {
            // Navigate to sign up
          },
          borderRadius: DesignRadius.borderSM,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DesignSpacing.xs,
              vertical: DesignSpacing.xs,
            ),
            child: Text(
              'Sign Up',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
