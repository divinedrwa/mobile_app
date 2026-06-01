import '../../../../core/utils/xfile_image_provider.dart';
import '../../../../core/services/multipart_file_factory.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  XFile? _selectedImage;
  bool _isSubmitting = false;

  static const _kPageBg = DesignColors.background;

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: DesignColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(icon, color: DesignColors.primary, size: 22),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      border: OutlineInputBorder(borderRadius: DesignRadius.borderXL),
      enabledBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderXL,
        borderSide: const BorderSide(color: DesignColors.borderLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderXL,
        borderSide: const BorderSide(color: DesignColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderXL,
        borderSide: const BorderSide(color: DesignColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: DesignRadius.borderXL,
        borderSide: const BorderSide(color: DesignColors.error, width: 1.5),
      ),
      labelStyle: DesignTypography.label.copyWith(color: DesignColors.textSecondary),
      hintStyle: DesignTypography.body.copyWith(color: DesignColors.textTertiary),
    );
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: _kPageBg,
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              backgroundColor: DesignColors.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                tooltip: 'Go back',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: DesignColors.textPrimary,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                'Edit Profile',
                style: DesignTypography.headingL.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: DesignColors.borderLight),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                DesignSpacing.lg,
                DesignSpacing.xl,
                DesignSpacing.lg,
                DesignSpacing.xxxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _sectionHeader(
                    title: 'Profile photo',
                    subtitle: 'Visible to your society directory',
                  ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0),
                  const SizedBox(height: DesignSpacing.md),
                  _photoCard(context, user).animate().fadeIn(duration: 320.ms).slideY(begin: DesignAnimations.slideNormal, end: 0),
                  const SizedBox(height: DesignSpacing.xxl),
                  _sectionHeader(
                    title: 'Personal details',
                    subtitle: 'We use this for notices and billing',
                  ).animate().fadeIn(delay: DesignAnimations.staggerFor(1), duration: DesignAnimations.durationEntrance),
                  const SizedBox(height: DesignSpacing.md),
                  _whiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: DesignTypography.body.copyWith(color: DesignColors.textPrimary),
                          decoration: _fieldDecoration(
                            label: 'Full name',
                            icon: Icons.person_outline_rounded,
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              v?.trim().isEmpty ?? true ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: DesignSpacing.lg),
                        TextFormField(
                          controller: _emailController,
                          style: DesignTypography.body.copyWith(color: DesignColors.textPrimary),
                          decoration: _fieldDecoration(
                            label: 'Email',
                            icon: Icons.alternate_email_rounded,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: DesignSpacing.lg),
                        TextFormField(
                          controller: _phoneController,
                          style: DesignTypography.body.copyWith(color: DesignColors.textPrimary),
                          decoration: _fieldDecoration(
                            label: 'Phone',
                            icon: Icons.phone_android_rounded,
                            hint: 'Optional',
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          validator: Validators.phoneOptional,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: DesignAnimations.staggerFor(1), duration: 320.ms).slideY(begin: DesignAnimations.slideSubtle, end: 0),
                  const SizedBox(height: DesignSpacing.xxl),
                  _sectionHeader(
                    title: 'Account',
                    subtitle: 'Managed by your society admin',
                  ).animate().fadeIn(delay: DesignAnimations.staggerFor(2), duration: DesignAnimations.durationEntrance),
                  const SizedBox(height: DesignSpacing.md),
                  _whiteCard(
                    child: Column(
                      children: [
                        _readOnlyRow(
                          icon: Icons.home_work_outlined,
                          iconBg: const Color(0xFFE8F0FE),
                          iconColor: DesignColors.primary,
                          label: 'Property',
                          value: user?.effectivePropertyDisplay?.trim().isNotEmpty == true
                              ? user!.effectivePropertyDisplay!.trim()
                              : '—',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: DesignSpacing.sm),
                          child: Divider(height: 1, color: DesignColors.borderLight.withValues(alpha: 0.9)),
                        ),
                        _readOnlyRow(
                          icon: Icons.layers_outlined,
                          iconBg: const Color(0xFFF3E8FF),
                          iconColor: const Color(0xFF7C3AED),
                          label: 'Unit / floor',
                          value: user?.effectiveUnitDisplay?.trim().isNotEmpty == true
                              ? user!.effectiveUnitDisplay!.trim()
                              : '—',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: DesignSpacing.sm),
                          child: Divider(height: 1, color: DesignColors.borderLight.withValues(alpha: 0.9)),
                        ),
                        _readOnlyRow(
                          icon: Icons.badge_outlined,
                          iconBg: const Color(0xFFE0F2FE),
                          iconColor: const Color(0xFF0284C7),
                          label: 'Occupant type',
                          value: user?.effectiveOccupantDisplay?.trim().isNotEmpty == true
                              ? user!.effectiveOccupantDisplay!.trim()
                              : '—',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: DesignSpacing.sm),
                          child: Divider(height: 1, color: DesignColors.borderLight.withValues(alpha: 0.9)),
                        ),
                        _readOnlyRow(
                          icon: Icons.apartment_rounded,
                          iconBg: const Color(0xFFF0FDF4),
                          iconColor: const Color(0xFF16A34A),
                          label: 'Society',
                          value: user?.societyName?.trim().isNotEmpty == true
                              ? user!.societyName!.trim()
                              : '—',
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: DesignAnimations.staggerFor(2), duration: 320.ms).slideY(begin: DesignAnimations.slideSubtle, end: 0),
                  const SizedBox(height: DesignSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignRadius.borderXL,
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 22),
                                const SizedBox(width: DesignSpacing.sm),
                                Text(
                                  'Save changes',
                                  style: DesignTypography.button.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: DesignAnimations.staggerFor(3), duration: 320.ms),
                  const SizedBox(height: DesignSpacing.lg),
                  Text(
                    'Changes apply to your resident profile immediately.',
                    textAlign: TextAlign.center,
                    style: DesignTypography.caption.copyWith(
                      color: DesignColors.textTertiary,
                      height: 1.35,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DesignTypography.headingM.copyWith(
            fontWeight: FontWeight.w700,
            color: DesignColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: DesignTypography.bodySmall.copyWith(
            color: DesignColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DesignRadius.borderXL,
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _photoCard(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DesignSpacing.xl),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DesignRadius.borderXL,
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: DesignColors.primary.withValues(alpha: 0.12),
                  backgroundImage: _selectedImage != null
                      ? xfileImageProvider(_selectedImage!)
                      : _networkAvatarProvider(user?.photoUrl),
                  child: _selectedImage == null &&
                          resolveServerFileUrl(user?.photoUrl) == null
                      ? Text(
                          (user?.name.isNotEmpty ?? false)
                              ? user!.name.substring(0, 1).toUpperCase()
                              : 'U',
                          style: DesignTypography.headingXL.copyWith(
                            color: DesignColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 44,
                            height: 1,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Material(
                  color: DesignColors.primary,
                  elevation: 4,
                  shadowColor: DesignColors.primary.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickImage,
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignSpacing.md),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('Choose from gallery'),
            style: TextButton.styleFrom(
              foregroundColor: DesignColors.primary,
              textStyle: DesignTypography.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: DesignRadius.borderLG,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: DesignSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: DesignTypography.caption.copyWith(
                  color: DesignColors.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: DesignTypography.bodyMedium.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ImageProvider? _networkAvatarProvider(String? photoUrl) {
    final u = resolveServerFileUrl(photoUrl);
    if (u == null) return null;
    return NetworkImage(u);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final jsonBody = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
      };

      final previousPhotoUrl = resolveServerFileUrl(
        ref.read(authProvider).user?.photoUrl,
      );

      if (_selectedImage != null) {
        final formData = FormData.fromMap({
          ...jsonBody,
          'image': await createMultipartFile(_selectedImage!),
        });
        try {
          await DioClient.dio.patch(ApiEndpoints.profile, data: formData);
        } on DioException {
          await DioClient.dio.put(ApiEndpoints.profile, data: formData);
        }
      } else {
        try {
          await DioClient.dio.patch(ApiEndpoints.profile, data: jsonBody);
        } on DioException {
          await DioClient.dio.put(ApiEndpoints.profile, data: jsonBody);
        }
      }

      // Refresh profile only — invalidating auth would briefly clear the user
      // and bounce the router back to society selection.
      await ref.read(authProvider.notifier).refreshProfile();

      // If the user uploaded a new image, drop any cached bytes for the
      // previous URL so the home header re-fetches (covers the edge case
      // where the backend returns the same URL with updated content).
      if (_selectedImage != null && previousPhotoUrl != null) {
        await CachedNetworkImage.evictFromCache(previousPhotoUrl);
        await NetworkImage(previousPhotoUrl).evict();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: DesignColors.success,
        ),
      );
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = mapDioException(e, 'Failed to update profile').message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: DesignColors.error,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: DesignColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
