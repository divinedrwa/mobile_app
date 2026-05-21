import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/dio_exception_mapper.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/emergency_contact_provider.dart';
import 'add_emergency_contact_screen.dart';

/// Emergency Contacts Screen
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(emergencyContactProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.state.denied.solid,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Emergency Contacts'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(emergencyContactProvider.notifier).fetchContacts(),
        child: contactsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.error_outline,
            title: 'Could not load emergency contacts',
            message: userFacingMessage(error),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(emergencyContactProvider.notifier).fetchContacts(),
          ),
        )]),
        data: (contacts) {
          if (contacts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [EmptyStateWidget(
              icon: Icons.emergency_outlined,
              title: 'No emergency contacts',
              subtitle:
                  'Add trusted contacts who will be notified during SOS alerts.',
              actionLabel: 'Add contact',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const AddEmergencyContactScreen(),
                ),
              ),
            )]);
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.spacing.s16),
            children: [
              const EnterpriseInfoBanner(
                icon: Icons.warning_amber_rounded,
                title: 'SOS alert recipients',
                message:
                    'These contacts will be notified immediately when you trigger an SOS alert.',
                tone: EnterpriseTone.danger,
              ),
              SizedBox(height: context.spacing.s24),
              EnterpriseSectionHeader(
                title: 'Emergency contacts',
                subtitle:
                    '${contacts.length} ${contacts.length == 1 ? 'contact' : 'contacts'} configured',
              ),
              SizedBox(height: context.spacing.s12),
              for (int index = 0; index < contacts.length; index++)
                _EmergencyContactCard(
                  contact: contacts[index],
                  onDelete: () =>
                      _deleteContact(context, ref, contacts[index].id),
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: DesignAnimations.staggerFor(index),
                    ),
            ],
          );
        },
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const AddEmergencyContactScreen(),
            ),
          );
        },
        backgroundColor: context.state.denied.solid,
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
    );
  }

  void _deleteContact(BuildContext context, WidgetRef ref, String? id) async {
    if (id == null || id.isEmpty) return;
    final ok = await ref
        .read(emergencyContactProvider.notifier)
        .deleteContact(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Contact removed' : 'Failed to remove contact'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }
}

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({
    required this.contact,
    required this.onDelete,
  });

  final dynamic contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s12),
      child: EnterprisePanel(
        tone: EnterpriseTone.danger,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.state.denied.bg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.emergency_outlined,
                color: context.state.denied.solid,
                size: 24,
              ),
            ),
            SizedBox(width: context.spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    contact.relationship,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    contact.phone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacing.s8),
            IconButton(
              tooltip: 'Call',
              icon: Icon(
                Icons.call_rounded,
                color: context.state.approved.solid,
              ),
              onPressed: () => _makeCall(contact.phone),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.state.denied.solid,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
