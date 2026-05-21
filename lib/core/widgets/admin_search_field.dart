import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Compact search field reused across admin list screens.
///
/// Renders a rounded text field with a search icon and optional clear button.
/// The caller owns the [TextEditingController] and [onChanged] callback.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: DesignTypography.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: DesignTypography.bodySmall
            .copyWith(color: DesignColors.textTertiary),
        prefixIcon: const Icon(Icons.search, size: 20, color: DesignColors.textTertiary),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: DesignColors.textTertiary,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: DesignColors.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignRadius.full),
          borderSide: BorderSide(color: DesignColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignRadius.full),
          borderSide: BorderSide(color: DesignColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignRadius.full),
          borderSide: const BorderSide(color: DesignColors.primary),
        ),
      ),
    );
  }
}
