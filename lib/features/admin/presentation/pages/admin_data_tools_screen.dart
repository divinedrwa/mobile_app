import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for CSV import/export of data.
class AdminDataToolsScreen extends ConsumerStatefulWidget {
  const AdminDataToolsScreen({super.key});

  @override
  ConsumerState<AdminDataToolsScreen> createState() =>
      _AdminDataToolsScreenState();
}

class _AdminDataToolsScreenState extends ConsumerState<AdminDataToolsScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Data Tools',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Import section — requires file_picker package (not yet installed)
          EnterpriseSectionHeader(title: 'Import CSV'),
          const SizedBox(height: 8),
          EnterprisePanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _actionTile(
                  icon: Icons.home_work_outlined,
                  label: 'Import Villas',
                  subtitle: 'Upload a CSV with villa data',
                  trailing: const Icon(Icons.upload_file, size: 18, color: DesignColors.textTertiary),
                  onTap: () => _showImportInfo(),
                ),
                const Divider(height: 1),
                _actionTile(
                  icon: Icons.people_outlined,
                  label: 'Import Residents',
                  subtitle: 'Upload a CSV with resident data',
                  trailing: const Icon(Icons.upload_file, size: 18, color: DesignColors.textTertiary),
                  onTap: () => _showImportInfo(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Export section
          EnterpriseSectionHeader(title: 'Export CSV'),
          const SizedBox(height: 8),
          EnterprisePanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _actionTile(
                  icon: Icons.home_work_outlined,
                  label: 'Export Villas',
                  subtitle: 'Download villa data as CSV',
                  trailing: const Icon(Icons.download, size: 18, color: DesignColors.textTertiary),
                  onTap: _exporting ? null : () => _handleExport('villas'),
                ),
                const Divider(height: 1),
                _actionTile(
                  icon: Icons.people_outlined,
                  label: 'Export Residents',
                  subtitle: 'Download resident data as CSV',
                  trailing: const Icon(Icons.download, size: 18, color: DesignColors.textTertiary),
                  onTap: _exporting ? null : () => _handleExport('residents'),
                ),
              ],
            ),
          ),
          if (_exporting) ...[
            const SizedBox(height: 8),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return EnterpriseActionTile(
      icon: icon,
      title: label,
      subtitle: subtitle,
      onTap: onTap,
      trailing: trailing,
    );
  }

  void _showImportInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV import requires file_picker package. Use the web admin panel for imports.'),
      ),
    );
  }

  Future<void> _handleExport(String type) async {
    setState(() => _exporting = true);
    try {
      final repo = ref.read(adminDataToolsRepositoryProvider);
      if (type == 'villas') {
        await repo.exportVillasCsv();
      } else {
        await repo.exportResidentsCsv();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_capitalize(type)} CSV exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
