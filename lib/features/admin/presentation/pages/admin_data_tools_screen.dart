import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _importing = false;

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
          // Import section
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
                  onTap: _importing ? null : () => _handleImport('villas'),
                ),
                const Divider(height: 1),
                _actionTile(
                  icon: Icons.people_outlined,
                  label: 'Import Residents',
                  subtitle: 'Upload a CSV with resident data',
                  trailing: const Icon(Icons.upload_file, size: 18, color: DesignColors.textTertiary),
                  onTap: _importing ? null : () => _handleImport('residents'),
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
          if (_exporting || _importing) ...[
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _importing ? 'Importing…' : 'Exporting…',
                    style: const TextStyle(fontSize: 13, color: DesignColors.textSecondary),
                  ),
                ],
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

  Future<void> _handleImport(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file data')),
        );
      }
      return;
    }

    setState(() => _importing = true);
    try {
      final repo = ref.read(adminDataToolsRepositoryProvider);
      final res = type == 'villas'
          ? await repo.importVillasCsv(file.bytes!, file.name)
          : await repo.importResidentsCsv(file.bytes!, file.name);
      if (mounted) {
        final count = res['created'] ?? res['imported'] ?? res['count'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_capitalize(type)} imported successfully${count != '' ? ' ($count records)' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _handleExport(String type) async {
    setState(() => _exporting = true);
    try {
      final repo = ref.read(adminDataToolsRepositoryProvider);
      final Uint8List bytes = type == 'villas'
          ? await repo.exportVillasCsv()
          : await repo.exportResidentsCsv();
      final filename =
          '${type}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$filename';
      await File(path).writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(path)],
        text: '${_capitalize(type)} export',
      );
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
