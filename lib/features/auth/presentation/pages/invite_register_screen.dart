import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/theme/design_tokens.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

/// Self-service signup with an admin invitation token (resident / guard / admin).
class InviteRegisterScreen extends ConsumerStatefulWidget {
  const InviteRegisterScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<InviteRegisterScreen> createState() =>
      _InviteRegisterScreenState();
}

class _InviteRegisterScreenState extends ConsumerState<InviteRegisterScreen> {
  final _token = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _villaId = TextEditingController();

  bool _checking = false;
  bool _submitting = false;

  Map<String, dynamic>? _verifyRoot;
  bool? _validInvite;

  String? get _invRole {
    final inv = _verifyRoot?['invitation'];
    if (inv is Map) return inv['role']?.toString();
    return null;
  }

  /// Server-side villa lock for this invitation (resident).
  String? get _inviteVillaIdAssigned {
    final inv = _verifyRoot?['invitation'];
    if (inv is! Map) return null;
    final id = inv['villaId']?.toString();
    if (id != null && id.isNotEmpty) return id;
    final villa = inv['villa'];
    if (villa is Map && villa['id'] != null) {
      return villa['id'].toString();
    }
    return null;
  }

  String? get _inviteVillaDisplay {
    final inv = _verifyRoot?['invitation'];
    if (inv is! Map) return null;
    final villa = inv['villa'];
    if (villa is Map) {
      final num = villa['villaNumber']?.toString() ?? '';
      final block = villa['block']?.toString();
      if (num.isEmpty) return null;
      if (block != null && block.isNotEmpty) return '$num ($block)';
      return num;
    }
    if (inv['villaId'] != null &&
        inv['villaId'].toString().trim().isNotEmpty) {
      return 'Assigned on invite';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final t = widget.initialToken?.trim();
    if (t != null && t.length >= 16) {
      _token.text = t;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verify();
      });
    }
  }

  @override
  void dispose() {
    _token.dispose();
    _username.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _villaId.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final raw = _token.text.trim();
    if (raw.length < 16) {
      _toast('Enter a valid invitation token');
      return;
    }
    setState(() {
      _checking = true;
      _verifyRoot = null;
      _validInvite = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final data = await repo.verifyInvitationToken(raw);
      final inv = data['invitation'];
      if (inv is Map) {
        final em = inv['email']?.toString();
        final ph = inv['phone']?.toString();
        if (em != null && em.isNotEmpty) _email.text = em;
        if (ph != null && ph.isNotEmpty) _phone.text = ph;
      }
      setState(() {
        _verifyRoot = data;
        _validInvite = data['valid'] == true;
      });
      if (_validInvite != true) {
        _toast('This invite is not active.');
      }
    } on AppException catch (e) {
      _toast(e.message);
      setState(() => _validInvite = false);
    } catch (e) {
      _toast('Could not verify invite');
      setState(() => _validInvite = false);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: DesignColors.error),
    );
  }

  Future<void> _submit() async {
    if (_validInvite != true) {
      _toast('Verify the invitation first');
      return;
    }
    final pw = _password.text;
    if (pw.length < 6) {
      _toast('Password must be at least 6 characters');
      return;
    }
    setState(() => _submitting = true);
    final ok = await ref.read(authProvider.notifier).registerWithInvitation(
          token: _token.text.trim(),
          username: _username.text.trim(),
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: pw,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          villaId: _invRole == 'RESIDENT' &&
                  _inviteVillaIdAssigned == null &&
                  _villaId.text.trim().isNotEmpty
              ? _villaId.text.trim()
              : null,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      final user = ref.read(authProvider).user;
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${user.name}!'),
            backgroundColor: DesignColors.success,
          ),
        );
      }
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Registration failed';
      _toast(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawInv = _verifyRoot?['invitation'];
    final inv =
        rawInv is Map ? Map<String, dynamic>.from(rawInv) : null;
    String? societyName;
    if (inv?['society'] is Map) {
      societyName = (inv!['society'] as Map)['name']?.toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join with invite'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the token from your administrator, verify it, then create your login.',
              style: TextStyle(color: DesignColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Invitation token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _checking ? null : _verify,
              child: Text(_checking ? 'Verifying…' : 'Verify'),
            ),
            if (inv != null) ...[
              const SizedBox(height: 16),
              Material(
                color: _validInvite == true
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (societyName != null)
                        Text(
                          societyName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      Text('Role: ${inv['role']}'),
                      if (_invRole == 'RESIDENT' &&
                          _inviteVillaDisplay != null) ...[
                        const SizedBox(height: 6),
                        Text('Assigned villa: $_inviteVillaDisplay'),
                      ],
                      if (_validInvite != true)
                        const Text(
                          'This invitation cannot be used right now.',
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (required if invitation used phone)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_invRole == 'RESIDENT' && _inviteVillaIdAssigned == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _villaId,
                decoration: const InputDecoration(
                  labelText: 'Villa ID (optional — only if not on invite)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_submitting || _validInvite != true) ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: DesignColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_submitting ? 'Creating account…' : 'Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
