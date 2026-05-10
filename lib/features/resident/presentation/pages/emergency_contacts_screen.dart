import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../data/providers/emergency_contact_provider.dart';
import 'add_emergency_contact_screen.dart';

/// Emergency Contacts Screen
class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(emergencyContactProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.red,
      ),
      body: contactsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(emergencyContactProvider.notifier).fetchContacts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (contacts) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              color: Colors.red.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 32),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'These contacts will be notified during SOS alerts',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: AppSpacing.md),
            ...contacts.asMap().entries.map((entry) {
              final index = entry.key;
              final contact = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    child: const Icon(Icons.emergency, color: Colors.red),
                  ),
                  title: Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.relationship),
                      Text(contact.phone, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Call',
                        icon: const Icon(Icons.call, color: Colors.green),
                        onPressed: () => _makeCall(contact.phone),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () =>
                            _deleteContact(context, ref, contact.id),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(
                duration: 300.ms,
                delay: DesignAnimations.staggerFor(index + 1),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEmergencyContactScreen(),
            ),
          );
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
    );
  }

  void _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
