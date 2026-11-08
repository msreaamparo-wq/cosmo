import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../providers/core_providers.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/parent_gate.dart';

/// Parent account: sign in / create account / forgot password. Children never need this.
class ParentAuthScreen extends ConsumerStatefulWidget {
  const ParentAuthScreen({super.key});
  @override
  ConsumerState<ParentAuthScreen> createState() => _ParentAuthScreenState();
}

class _ParentAuthScreenState extends ConsumerState<ParentAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted || ref.read(parentGateProvider)) return;
      final ok = await ParentGate.verify(context);
      if (!mounted) return;
      if (ok) {
        ref.read(parentGateProvider.notifier).pass();
      } else {
        context.canPop() ? context.pop() : context.go(CosmosRoutes.home);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    final e = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e))
      return 'Please enter a valid email address.';
    if (_password.text.length < 6)
      return 'Passwords need at least 6 characters.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() {
        _message = problem;
        _ok = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final auth = ref.read(authServiceProvider);
    final r = _signUp
        ? await auth.signUp(_email.text, _password.text)
        : await auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.message;
      _ok = r.ok;
    });
    if (r.ok && !_signUp && auth.currentUser != null) {
      await ref.read(syncControllerProvider.notifier).refreshStatus();
      if (mounted)
        context.canPop() ? context.pop() : context.go(CosmosRoutes.settings);
    }
  }

  Future<void> _forgot() async {
    final e = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      setState(() {
        _message = 'Type your email above first, then tap "Forgot password".';
        _ok = false;
      });
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(authServiceProvider).resetPassword(e);
    if (mounted)
      setState(() {
        _busy = false;
        _message = r.message;
        _ok = r.ok;
      });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final passed = ref.watch(parentGateProvider);
    return CosmicScaffold(
      title: 'Parent account',
      body: !passed
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                        'For grown-ups. A parent account is optional and only needed for cloud backup.',
                        style: text.bodyLarge
                            ?.copyWith(color: CosmosColors.softLavender)),
                    const SizedBox(height: 16),
                    if (!AppConfig.supabaseConfigured)
                      Text(
                          'Cloud is not set up in this build. See docs/SUPABASE_SETUP.md.',
                          style: text.bodyLarge
                              ?.copyWith(color: CosmosColors.coral)),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign in')),
                        ButtonSegment(
                            value: true, label: Text('Create account'))
                      ],
                      selected: {_signUp},
                      onSelectionChanged: (s) => setState(() {
                        _signUp = s.first;
                        _message = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                          labelText: 'Parent email',
                          prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: _signUp
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      onSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                            tooltip:
                                _obscure ? 'Show password' : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility
                                : Icons.visibility_off)),
                      ),
                    ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_message!,
                                style: text.bodyLarge?.copyWith(
                                    color: _ok
                                        ? CosmosColors.mint
                                        : CosmosColors.coral))),
                      ),
                    const SizedBox(height: 20),
                    CosmicButton(
                        label: _busy
                            ? 'One moment…'
                            : (_signUp ? 'Create account' : 'Sign in'),
                        icon: _signUp ? Icons.person_add : Icons.login,
                        expand: true,
                        onPressed: _busy ? null : _submit),
                    if (!_signUp)
                      TextButton(
                          style: TextButton.styleFrom(
                              minimumSize: const Size(64, 48)),
                          onPressed: _busy ? null : _forgot,
                          child: const Text('Forgot password?')),
                  ],
                ),
              ),
            ),
    );
  }
}
