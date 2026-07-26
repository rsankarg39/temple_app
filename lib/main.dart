import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/temple_models.dart';
import 'providers/pending_temple_provider.dart';
import 'providers/temple_session.dart';
import 'supabase/temple_repository.dart';
import 'supabase_config.dart';
import 'privacy_policy_page.dart';
import 'theme/app_theme.dart';
import 'theme/responsive_layout.dart';
import 'widgets/temple_auth_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.preloadFonts();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const ProviderScope(child: TempleBookApp()));
}

class TempleBookApp extends StatelessWidget {
  const TempleBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temple Book',
      theme: AppTheme.light(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: Responsive.textScalerFor(context, media.textScaler),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (_, snapshot) {
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordPage();
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const AuthPage();
        return const MpinGate();
      },
    );
  }
}

class MpinGate extends ConsumerStatefulWidget {
  const MpinGate({super.key});

  @override
  ConsumerState<MpinGate> createState() => _MpinGateState();
}

class _MpinGateState extends ConsumerState<MpinGate> {
  bool _verified = false;
  late final Future<_MpinGateDecision> _decisionFuture;

  @override
  void initState() {
    super.initState();
    _decisionFuture = _resolveDecision();
  }

  Future<_MpinGateDecision> _resolveDecision() async {
    final repo = ref.read(repoProvider);
    if (await repo.consumePasswordLoginBypass()) {
      return const _MpinGateDecision(skipMpin: true, hasMpin: false);
    }
    final hasMpin = await repo.hasMpin();
    return _MpinGateDecision(skipMpin: false, hasMpin: hasMpin);
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      return TempleGate(onReady: const HomePage());
    }
    return FutureBuilder<_MpinGateDecision>(
      future: _decisionFuture,
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const TempleAuthScaffold(
            title: 'Please wait',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final decision = snapshot.data!;
        if (decision.skipMpin) {
          return TempleGate(onReady: const HomePage());
        }
        final hasMpin = decision.hasMpin;
        if (!hasMpin) {
          return SetMpinPage(onSaved: () => setState(() => _verified = true));
        }
        return VerifyMpinPage(
          onVerified: () => setState(() => _verified = true),
        );
      },
    );
  }
}

class _MpinGateDecision {
  const _MpinGateDecision({required this.skipMpin, required this.hasMpin});
  final bool skipMpin;
  final bool hasMpin;
}

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  int _authTabIndex = 0;
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _name = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPhone = TextEditingController();
  final _registerBusiness = TextEditingController();
  final _registerPhoto = TextEditingController();
  final _registerPassword = TextEditingController();
  final _registerMpin = TextEditingController();
  final _registerConfirmMpin = TextEditingController();
  String? _registerGender;
  String? _registerKulam;
  String? _registerMaritalStatus;
  String? _selectedTempleId;
  List<Temple> _availableTemples = [];
  bool _templesLoading = true;

  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> _kulamOptions = [
    'Bharadwaja',
    'Kashyapa',
    'Vasishta',
    'Atri',
    'Gautama',
    'Other',
  ];
  static const List<String> _maritalStatusOptions = [
    'Single',
    'Married',
    'Widowed',
    'Divorced',
  ];

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  Future<void> _loadTemples() async {
    try {
      final temples = await ref.read(repoProvider).getActiveTemples();
      if (!mounted) return;
      await ref
          .read(pendingTempleProvider.notifier)
          .syncFromTempleList(temples);
      if (!mounted) return;
      setState(() {
        _availableTemples = temples;
        _selectedTempleId = ref.read(pendingTempleProvider)?.id ??
            (temples.length == 1 ? temples.first.id : null);
        _templesLoading = false;
      });
    } catch (_) {
      if (mounted) {
        final fallback = [
          Temple(id: defaultTempleId, name: 'Default Temple'),
        ];
        await ref
            .read(pendingTempleProvider.notifier)
            .syncFromTempleList(fallback);
        if (!mounted) return;
        setState(() {
          _availableTemples = fallback;
          _selectedTempleId = defaultTempleId;
          _templesLoading = false;
        });
      }
    }
  }

  Widget _templePicker() {
    return TemplePickerField(
      temples: _availableTemples,
      selectedId: _selectedTempleId,
      loading: _templesLoading,
      onChanged: (id) => setState(() => _selectedTempleId = id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TempleAuthScaffold(
      title: 'Temple Book',
      headerBelowBanner: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: _templePicker(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Login')),
                      ButtonSegment(value: 1, label: Text('Register')),
                    ],
                    selected: {_authTabIndex},
                    onSelectionChanged: (value) {
                      setState(() => _authTabIndex = value.first);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Privacy Policy',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.privacy_tip_outlined),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'By continuing, you agree to our privacy policy.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _authTabIndex,
              children: [
                AuthScrollBody(children: _loginFields()),
                AuthScrollBody(children: _registerFields()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _loginFields() {
    return [
        TextField(
          controller: _loginEmail,
          decoration: const InputDecoration(labelText: 'Email'),
              segments: const [
                ButtonSegment(value: 0, label: Text('Login')),
                ButtonSegment(value: 1, label: Text('Register')),
              ],
              selected: {_authTabIndex},
              onSelectionChanged: (value) {
                setState(() => _authTabIndex = value.first);
              },
            ),
          ),
    );
  }

  List<Widget> _loginFields() {
    return [
        TextField(
          controller: _loginEmail,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _loginPassword,
          decoration: const InputDecoration(labelText: 'Password'),
          keyboardType: TextInputType.text,
          obscureText: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ForgotPasswordPage(
                    initialEmail: _loginEmail.text.trim(),
                  ),
                ),
              );
            },
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            if (_selectedTempleId == null) {
              _showMessage('Select your temple first');
              return;
            }
            final email = _loginEmail.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              _showMessage('Enter a valid email address');
              return;
            }
            if (_loginPassword.text.isEmpty) {
              _showMessage('Enter password');
              return;
            }
            final temple = _availableTemples
                .where((t) => t.id == _selectedTempleId)
                .firstOrNull;
            if (temple != null) {
              await ref.read(pendingTempleProvider.notifier).select(temple);
            }
            try {
              await ref
                  .read(repoProvider)
                  .signInWithEmailPassword(
                    email: email,
                    password: _loginPassword.text,
                  );
              await ref.read(repoProvider).ensureCurrentProfileExists();
              await ref.read(repoProvider).markPasswordLoginBypass();
            } catch (e) {
              _showMessage(_friendlyAuthError(e, action: 'login'));
            }
          },
          child: const Text('Login'),
        ),
    ];
  }

  List<Widget> _registerFields() {
    return [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _registerGender,
          decoration: const InputDecoration(labelText: 'Gender *'),
          items: _genderOptions
              .map(
                (value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => _registerGender = value),
        ),
        DropdownButtonFormField<String>(
          initialValue: _registerKulam,
          decoration: const InputDecoration(labelText: 'Kulam *'),
          items: _kulamOptions
              .map(
                (value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => _registerKulam = value),
        ),
        DropdownButtonFormField<String>(
          initialValue: _registerMaritalStatus,
          decoration: const InputDecoration(labelText: 'Marital Status *'),
          items: _maritalStatusOptions
              .map(
                (value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => _registerMaritalStatus = value),
        ),
        TextField(
          controller: _registerEmail,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        TextField(
          controller: _registerPhone,
          decoration: const InputDecoration(
            labelText: 'Phone Number (optional)',
          ),
          keyboardType: TextInputType.phone,
          maxLength: 10,
        ),
        TextField(
          controller: _registerBusiness,
          decoration: const InputDecoration(labelText: 'Business (optional)'),
        ),
        TextField(
          controller: _registerPhoto,
          decoration: const InputDecoration(labelText: 'Photo URL (optional)'),
        ),
        TextField(
          controller: _registerPassword,
          decoration: const InputDecoration(
            labelText: 'Password (minimum 6 characters)',
          ),
          obscureText: true,
        ),
        TextField(
          controller: _registerMpin,
          decoration: const InputDecoration(
            labelText: '4-digit MPIN (optional)',
          ),
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
        ),
        TextField(
          controller: _registerConfirmMpin,
          decoration: const InputDecoration(labelText: 'Confirm MPIN'),
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            if (_selectedTempleId == null) {
              _showMessage('Select your temple first');
              return;
            }
            if (_registerGender == null ||
                _registerKulam == null ||
                _registerMaritalStatus == null) {
              _showMessage('Gender, Kulam and Marital Status are mandatory');
              return;
            }
            final email = _registerEmail.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              _showMessage('Enter a valid email address');
              return;
            }
            final phone = _registerPhone.text.trim();
            if (phone.isNotEmpty && !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
              _showMessage(
                'Enter a valid 10-digit Indian phone number or leave it blank',
              );
              return;
            }
            final mpin = _registerMpin.text.trim();
            final confirmMpin = _registerConfirmMpin.text.trim();
            if (mpin.isNotEmpty || confirmMpin.isNotEmpty) {
              if (mpin != confirmMpin) {
                _showMessage('MPIN and confirm MPIN must match');
                return;
              }
              if (!RegExp(r'^\d{4}$').hasMatch(mpin)) {
                _showMessage('MPIN must be exactly 4 digits');
                return;
              }
            }
            final passwordToUse = _registerPassword.text.trim();

            if (passwordToUse.isEmpty || passwordToUse.length < 6) {
              _showMessage('Password must be at least 6 characters');
              return;
            }
            try {
              await ref
                  .read(repoProvider)
                  .signUpWithEmailPassword(
                    name: _name.text.trim(),
                    email: email,
                    password: passwordToUse,
                    templeId: _selectedTempleId!,
                    phone: phone.isNotEmpty ? phone : null,
                    mpin: mpin.isNotEmpty ? mpin : null,
                    gender: _registerGender!,
                    kulam: _registerKulam!,
                    maritalStatus: _registerMaritalStatus!,
                    business: _registerBusiness.text.trim().isEmpty
                        ? null
                        : _registerBusiness.text.trim(),
                    photoUrl: _registerPhoto.text.trim().isEmpty
                        ? null
                        : _registerPhoto.text.trim(),
                  );
              _showMessage(
                'Registration successful. Login with your email and password.',
              );
              setState(() => _authTabIndex = 0);
            } catch (e) {
              _showMessage(_friendlyAuthError(e, action: 'registration'));
            }
          },
          child: const Text('Register'),
        ),
    ];
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthError(Object e, {required String action}) {
    final msg = e.toString();
    if (msg.contains('email_not_confirmed')) {
      return 'Email not confirmed. Please verify your email and try again.';
    }
    if (msg.contains('Invalid login credentials')) {
      return 'Invalid credentials. Please check email and password.';
    }
    return '${action[0].toUpperCase()}${action.substring(1)} failed: $e';
  }
}

/// Request a password reset link by email (Supabase Auth).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({this.initialEmail = '', super.key});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final TextEditingController _email;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TempleAuthScaffold(
      title: 'Reset Password',
      body: AuthScrollBody(
        children: [
          Text(
            'Enter the email you used to register. We will send you a link to set a new password.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enabled: !_sending,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _sendResetLink,
            child: _sending
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send reset link'),
          ),
          const SizedBox(height: 12),
          Text(
            'Check your inbox and spam folder. The link may open in your browser; '
            'after setting a new password, return here and log in.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendResetLink() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _show('Enter a valid email address');
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(repoProvider).sendPasswordResetEmail(email);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Check your email'),
          content: Text(
            'If an account exists for $email, you will receive a password reset link shortly.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to login'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        _show('Could not send reset email. Try again or contact your temple admin.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Shown when the user opens the app from the password reset email link.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TempleAuthScaffold(
      title: 'Set New Password',
      body: AuthScrollBody(
        children: [
          const Text(
            'Choose a new password for your account (at least 6 characters).',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'New password'),
            obscureText: true,
            enabled: !_saving,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            obscureText: true,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _savePassword,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save password'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    await ref.read(repoProvider).signOut();
                  },
            child: const Text('Cancel and return to login'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePassword() async {
    final password = _password.text;
    final confirm = _confirm.text;
    if (password.length < 6) {
      _show('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      _show('Passwords do not match');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(repoProvider).updatePassword(password);
      await ref.read(repoProvider).markPasswordLoginBypass();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. You can continue into the app.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        _show('Could not update password: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class SetMpinPage extends ConsumerStatefulWidget {
  const SetMpinPage({required this.onSaved, super.key});

  final VoidCallback onSaved;

  @override
  ConsumerState<SetMpinPage> createState() => _SetMpinPageState();
}

class _SetMpinPageState extends ConsumerState<SetMpinPage> {
  final _mpin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensurePendingTempleLoaded(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TempleAuthScaffold(
      title: 'Set MPIN',
      actions: [
        IconButton(
          onPressed: () async => ref.read(repoProvider).signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
      body: AuthScrollBody(
        children: [
          const Text('Set a 4-digit MPIN for quick secure access.'),
          TextField(
            controller: _mpin,
            decoration: const InputDecoration(labelText: 'MPIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          TextField(
            controller: _confirm,
            decoration: const InputDecoration(labelText: 'Confirm MPIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              if (_mpin.text != _confirm.text) {
                _show('MPIN mismatch');
                return;
              }
              try {
                await ref.read(repoProvider).setMpin(_mpin.text);
                widget.onSaved();
              } catch (e) {
                _show('Unable to set MPIN: $e');
              }
            },
            child: const Text('Save MPIN'),
          ),
        ],
      ),
    );
  }

  void _show(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }
}

class VerifyMpinPage extends ConsumerStatefulWidget {
  const VerifyMpinPage({required this.onVerified, super.key});

  final VoidCallback onVerified;

  @override
  ConsumerState<VerifyMpinPage> createState() => _VerifyMpinPageState();
}

class _VerifyMpinPageState extends ConsumerState<VerifyMpinPage> {
  final _mpin = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensurePendingTempleLoaded(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TempleAuthScaffold(
      title: 'Verify MPIN',
      actions: [
        IconButton(
          onPressed: () async => ref.read(repoProvider).signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
      body: AuthScrollBody(
        children: [
          const Text('Enter your 4-digit MPIN'),
          TextField(
            controller: _mpin,
            decoration: const InputDecoration(labelText: 'MPIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              try {
                final ok = await ref.read(repoProvider).verifyMpin(_mpin.text);
                if (!ok) {
                  _show('Invalid MPIN');
                  return;
                }
                widget.onVerified();
              } catch (e) {
                _show('Unable to verify MPIN: $e');
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _show(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _showedPaymentHistory = false;
  int _railIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_showedPaymentHistory || !mounted) return;
      _showedPaymentHistory = true;
      await showPaymentHistoryOnLogin(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(templeSessionProvider);
    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<AppRole>(
      future: ref.read(repoProvider).getCurrentRole(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = snapshot.data!;
        final tabs = _tabsForRole(role);
        final useRail = Responsive.isExpanded(context);

        if (useRail) {
          if (_railIndex >= tabs.length) _railIndex = 0;
          return Scaffold(
            key: ValueKey('${session.temple.id}-rail'),
            appBar: AppBar(
              title: TempleDashboardTitle(
                templeName: session.temple.name,
                roleLabel: role.name.toUpperCase(),
              ),
              actions: _dashboardActions(context),
            ),
            body: Row(
              children: [
                NavigationRail(
                  extended: Responsive.widthOf(context) >= 1100,
                  selectedIndex: _railIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _railIndex = i),
                  labelType: NavigationRailLabelType.none,
                  destinations: tabs
                      .map(
                        (t) => NavigationRailDestination(
                          icon: Icon(dashboardTabIcon(t.title)),
                          selectedIcon: Icon(dashboardTabIcon(t.title)),
                          label: Text(
                            t.title,
                            style: TextStyle(
                              fontSize: Responsive.sp(
                                context,
                                compact: 12,
                                medium: 13,
                                expanded: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: tabs[_railIndex].page),
              ],
            ),
          );
        }

        final tabWidgets = tabs
            .map(
              (t) => responsiveDashboardTab(
                context,
                title: t.title,
                shortTitle: t.shortTitle,
              ),
            )
            .toList();

        return DefaultTabController(
          key: ValueKey(session.temple.id),
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: TempleDashboardTitle(
                templeName: session.temple.name,
                roleLabel: role.name.toUpperCase(),
              ),
              actions: _dashboardActions(context),
              bottom: responsiveDashboardTabBar(context, tabWidgets),
            ),
            body: TabBarView(children: tabs.map((t) => t.page).toList()),
          ),
        );
      },
    );
  }

  List<Widget> _dashboardActions(BuildContext context) => [
        IconButton(
          onPressed: () => showTempleSwitcher(context, ref),
          icon: const Icon(Icons.swap_horiz),
          tooltip: 'Switch temple',
        ),
        IconButton(
          onPressed: () async => ref.read(repoProvider).signOut(),
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
        ),
      ];
}

class _RoleTab {
  const _RoleTab({
    required this.title,
    required this.page,
    this.shortTitle,
  });
  final String title;
  final String? shortTitle;
  final Widget page;
}

List<_RoleTab> _tabsForRole(AppRole role) {
  switch (role) {
    case AppRole.admin:
      return const [
        _RoleTab(title: 'User Roles', shortTitle: 'Roles', page: UserRolesTab()),
        _RoleTab(title: 'Profiles', page: ProfilesTab()),
        _RoleTab(
          title: 'Family Heads',
          shortTitle: 'Family',
          page: FamilyHeadsTab(),
        ),
        _RoleTab(title: 'Committee', page: CommitteeTab()),
        _RoleTab(title: 'Payments', page: PaymentsTab()),
        _RoleTab(title: 'Pooja', page: PoojaTab()),
        _RoleTab(title: 'Events', page: EventsTab()),
        _RoleTab(title: 'Birthdays', shortTitle: "B'days", page: BirthdayTab()),
        _RoleTab(title: 'Employees', shortTitle: 'Staff', page: EmployeesTab()),
        _RoleTab(title: 'Temple Ops', shortTitle: 'Ops', page: TempleOpsTab()),
      ];
    case AppRole.committee:
      return const [
        _RoleTab(title: 'Payments', page: PaymentsTab(readOnly: true)),
        _RoleTab(title: 'Pooja', page: PoojaTab()),
        _RoleTab(title: 'Events', page: EventsTab()),
        _RoleTab(title: 'Birthdays', shortTitle: "B'days", page: BirthdayTab()),
        _RoleTab(
          title: 'Employees',
          shortTitle: 'Staff',
          page: EmployeesTab(readOnly: true),
        ),
        _RoleTab(
          title: 'Temple Ops',
          shortTitle: 'Ops',
          page: TempleOpsTab(readOnly: true),
        ),
      ];
    case AppRole.user:
      return const [
        _RoleTab(title: 'Payments', page: PaymentsTab(readOnly: true)),
        _RoleTab(title: 'Pooja', page: PoojaTab(readOnly: true)),
        _RoleTab(title: 'Events', page: EventsTab(readOnly: true)),
        _RoleTab(
          title: 'Employees',
          shortTitle: 'Staff',
          page: EmployeesTab(readOnly: true),
        ),
        _RoleTab(
          title: 'Temple Ops',
          shortTitle: 'Ops',
          page: TempleOpsTab(readOnly: true),
        ),
        _RoleTab(
          title: 'Committee Details',
          shortTitle: 'Committee',
          page: CommitteeTab(),
        ),
        _RoleTab(
          title: 'Admin Details',
          shortTitle: 'Admin',
          page: AdminDetailsTab(),
        ),
      ];
  }
}

class ProfilesTab extends ConsumerStatefulWidget {
  const ProfilesTab({super.key});

  @override
  ConsumerState<ProfilesTab> createState() => _ProfilesTabState();
}

class UserRolesTab extends ConsumerStatefulWidget {
  const UserRolesTab({super.key});

  @override
  ConsumerState<UserRolesTab> createState() => _UserRolesTabState();
}

class _UserRolesTabState extends ConsumerState<UserRolesTab> {
  int _reloadTick = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfileSummary>>(
      future: ref.read(repoProvider).getAllProfiles(),
      key: ValueKey(_reloadTick),
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        if (users.isEmpty) return const Center(child: Text('No users found'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            final currentRole = roleFromString(u.role);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 420;
                    final nameStyle = Theme.of(context).textTheme.titleSmall;
                    final emailStyle = Theme.of(context).textTheme.bodySmall;
                    final roleDropdown = DropdownButton<AppRole>(
                      isExpanded: narrow,
                      value: currentRole,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              if (value == null) return;
                              setState(() => _saving = true);
                              try {
                                await ref
                                    .read(repoProvider)
                                    .updateUserRole(
                                      profileId: u.id,
                                      role: value,
                                      fullName: u.fullName,
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Updated ${u.fullName} to ${value.name}',
                                    ),
                                  ),
                                );
                                setState(() => _reloadTick++);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text('Role update failed: $e'),
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            },
                      items: AppRole.values
                          .map(
                            (r) => DropdownMenuItem<AppRole>(
                              value: r,
                              child: Text(
                                r.name.toUpperCase(),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          )
                          .toList(),
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(u.fullName, style: nameStyle),
                          const SizedBox(height: 4),
                          Text(
                            u.email ?? 'No email',
                            style: emailStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          roleDropdown,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.fullName, style: nameStyle),
                              Text(
                                u.email ?? 'No email',
                                style: emailStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        roleDropdown,
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfilesTabState extends ConsumerState<ProfilesTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isFamilyHead = false;
  int? _selectedFamilyHeadId;
  DateTime? _dob;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FamilyHead>>(
      future: ref.read(repoProvider).getFamilyHeads(),
      builder: (context, snapshot) {
        final heads = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Add/Remove user profile'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            ListTile(
              title: Text(
                _dob == null
                    ? 'Select date of birth'
                    : DateFormat('dd MMM yyyy').format(_dob!),
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dob = picked);
              },
            ),
            CheckboxListTile(
              value: _isFamilyHead,
              onChanged: (v) => setState(() => _isFamilyHead = v ?? false),
              title: const Text('Is Family Head'),
            ),
            DropdownButtonFormField<int>(
              initialValue: _selectedFamilyHeadId,
              items: heads
                  .map(
                    (h) => DropdownMenuItem(
                      value: h.id,
                      child: Text('${h.name} (${h.nakshatram ?? '-'})'),
                    ),
                  )
                  .toList(),
              onChanged: !_isFamilyHead
                  ? (v) => setState(() => _selectedFamilyHeadId = v)
                  : null,
              decoration: const InputDecoration(
                labelText: 'Mandatory family association when not family head',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                if (_nameController.text.trim().isEmpty ||
                    _phoneController.text.trim().isEmpty)
                  return;
                if (!_isFamilyHead && _selectedFamilyHeadId == null) {
                  _showMessage(
                    'Select family head when member is not family head',
                  );
                  return;
                }
                await ref
                    .read(repoProvider)
                    .addFamilyHead(
                      name: _nameController.text.trim(),
                      phone: _phoneController.text.trim(),
                      nakshatram: _dob == null
                          ? null
                          : DateFormat('MM-dd').format(_dob!),
                    );
                _showMessage(
                  'Saved basic profile. Extend fields in schema for full profile set.',
                );
              },
              child: const Text('Save Profile'),
            ),
            const SizedBox(height: 8),
            const Text(
              'For fields like gender, kulam, marital status, email, social links, business, photo and contributions, add a `profiles` table.',
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class FamilyHeadsTab extends ConsumerWidget {
  const FamilyHeadsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<FamilyHead>>(
      future: ref.read(repoProvider).getFamilyHeads(),
      builder: (context, snapshot) {
        final heads = snapshot.data ?? [];
        if (heads.isEmpty) return const Center(child: Text('No family heads'));
        return ListView.builder(
          itemCount: heads.length,
          itemBuilder: (_, i) {
            final h = heads[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.groups_2)),
              title: Text(h.name),
              subtitle: Text(h.phone),
              trailing: Text(h.nakshatram ?? '-'),
            );
          },
        );
      },
    );
  }
}

class CommitteeTab extends ConsumerWidget {
  const CommitteeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<CommitteeMember>>(
      future: ref.read(repoProvider).getCommitteeMembers(),
      builder: (_, snapshot) {
        final members = snapshot.data ?? [];
        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (_, i) {
            final m = members[i];
            return ListTile(
              title: Text(m.name),
              subtitle: Text(m.role ?? 'Member'),
              trailing: const Icon(Icons.badge_outlined),
            );
          },
        );
      },
    );
  }
}

class PaymentsTab extends ConsumerStatefulWidget {
  const PaymentsTab({this.readOnly = false, super.key});

  final bool readOnly;

  @override
  ConsumerState<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<PaymentsTab> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  int _reloadTick = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final paymentsFuture = widget.readOnly
        ? repo.getMyPayments()
        : repo.getPayments();
    return FutureBuilder<List<PaymentEntry>>(
      future: paymentsFuture,
      key: ValueKey(_reloadTick),
      builder: (_, snapshot) {
        final payments = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.readOnly) ...[
              Text(
                'Your payment history at this temple',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No payments found for your name')),
                ),
              const Divider(height: 24),
            ],
            if (!widget.readOnly) ...[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Payer Name'),
              ),
              TextField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _purpose,
                decoration: const InputDecoration(labelText: 'Purpose'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: () async {
                      await _payByUpi();
                    },
                    child: const Text('Pay with UPI'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Temple donation receipt: ${_name.text} paid Rs.${_amount.text}',
                      ),
                    ),
                    child: const Text('Share receipt'),
                  ),
                ],
              ),
              const Divider(height: 24),
            ] else if (payments.isNotEmpty) ...[
              Text(
                'All temple payments',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Divider(height: 24),
            ],
            ...payments.map(
              (p) => ListTile(
                title: Text('${p.payer} - Rs.${p.amount.toStringAsFixed(2)}'),
                subtitle: Text(p.purpose ?? 'General donation'),
                trailing: widget.readOnly
                    ? const Icon(Icons.visibility_outlined)
                    : IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editPayment(p),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _payByUpi() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (_name.text.trim().isEmpty || amount <= 0) return;
    await ref
        .read(repoProvider)
        .addPayment(
          payer: _name.text.trim(),
          amount: amount,
          purpose: _purpose.text.trim().isEmpty ? null : _purpose.text.trim(),
        );
    final upiId = await ref.read(repoProvider).getTempleUpiId();
    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=Temple%20Trust&am=${amount.toStringAsFixed(2)}&cu=INR',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
    if (mounted) {
      setState(() => _reloadTick++);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment entry recorded')));
    }
  }

  Future<void> _editPayment(PaymentEntry payment) async {
    final payerController = TextEditingController(text: payment.payer);
    final amountController = TextEditingController(
      text: payment.amount.toString(),
    );
    final purposeController = TextEditingController(
      text: payment.purpose ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: payerController,
                decoration: const InputDecoration(labelText: 'Payer Name'),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              TextField(
                controller: purposeController,
                decoration: const InputDecoration(labelText: 'Purpose'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (payerController.text.trim().isEmpty || amount <= 0) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text) ?? 0;
      await ref
          .read(repoProvider)
          .updatePayment(
            id: payment.id,
            payer: payerController.text.trim(),
            amount: amount,
            purpose: purposeController.text.trim().isEmpty
                ? null
                : purposeController.text.trim(),
          );
      if (mounted) {
        setState(() => _reloadTick++);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment updated')));
      }
    }
    payerController.dispose();
    amountController.dispose();
    purposeController.dispose();
  }
}

class PoojaTab extends ConsumerStatefulWidget {
  const PoojaTab({this.readOnly = false, super.key});

  final bool readOnly;

  @override
  ConsumerState<PoojaTab> createState() => _PoojaTabState();
}

class _PoojaTabState extends ConsumerState<PoojaTab>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _description = TextEditingController();
  DateTime? _poojaDate;
  int _reloadTick = 0;
  late TabController _sectionController;

  @override
  void initState() {
    super.initState();
    _sectionController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          TabBar(
            controller: _sectionController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _sectionController,
              children: [
                _buildPoojaList(upcomingOnly: true),
                _buildPoojaList(pastOnly: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoojaList({bool upcomingOnly = false, bool pastOnly = false}) {
    return FutureBuilder<List<PoojaEntry>>(
      future: ref.read(repoProvider).getPoojas(
            upcomingOnly: upcomingOnly ? true : null,
            pastOnly: pastOnly ? true : null,
          ),
      key: ValueKey('$_reloadTick-$upcomingOnly-$pastOnly'),
      builder: (_, snapshot) {
        final poojas = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (upcomingOnly && !widget.readOnly) ...[
              Text(
                'Daily / Monthly / Yearly poojas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Pooja Name'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description / Timing',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _poojaDate == null
                      ? 'Pooja date (optional â€” leave blank for recurring)'
                      : DateFormat('dd MMM yyyy').format(_poojaDate!),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 3),
                      ),
                    );
                    if (picked != null) setState(() => _poojaDate = picked);
                  },
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _addPooja,
                child: const Text('Add Pooja'),
              ),
              const Divider(height: 24),
            ] else if (widget.readOnly && upcomingOnly) ...[
              Text(
                'Current and upcoming poojas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Divider(height: 16),
            ] else if (pastOnly) ...[
              Text(
                'Past poojas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Divider(height: 16),
            ],
            if (poojas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    upcomingOnly
                        ? 'No current or upcoming poojas'
                        : 'No past poojas',
                  ),
                ),
              ),
            ...poojas.map(
              (p) => Card(
                child: ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    [
                      if (p.poojaDate != null)
                        DateFormat('dd MMM yyyy').format(p.poojaDate!),
                      p.description ?? 'Description / time to be added',
                    ].where((s) => s.isNotEmpty).join(' Â· '),
                  ),
                  trailing: widget.readOnly || pastOnly
                      ? const Icon(Icons.visibility_outlined)
                      : FilledButton(
                          onPressed: () => _bookPooja(context, p.name),
                          child: const Text('Book'),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPooja() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref.read(repoProvider).addPooja(
          name: name,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          poojaDate: _poojaDate,
        );
    _name.clear();
    _description.clear();
    if (mounted) {
      setState(() {
        _poojaDate = null;
        _reloadTick++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pooja entry added')));
    }
  }

  void _bookPooja(BuildContext context, String poojaName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pooja booking initiated for $poojaName. Integrate payment table.',
        ),
      ),
    );
  }
}

class AdminDetailsTab extends ConsumerWidget {
  const AdminDetailsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<UserProfileSummary>>(
      future: ref.read(repoProvider).getProfilesByRole('admin'),
      builder: (_, snapshot) {
        final admins = snapshot.data ?? [];
        if (admins.isEmpty)
          return const Center(child: Text('No admin details available'));
        return ListView.builder(
          itemCount: admins.length,
          itemBuilder: (_, i) {
            final admin = admins[i];
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              title: Text(admin.fullName),
              subtitle: Text(admin.email ?? 'No email'),
              trailing: const Icon(Icons.visibility_outlined),
            );
          },
        );
      },
    );
  }
}

class EventsTab extends ConsumerStatefulWidget {
  const EventsTab({this.readOnly = false, super.key});

  final bool readOnly;

  @override
  ConsumerState<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<EventsTab> {
  final _title = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventEntry>>(
      future: ref.read(repoProvider).getEvents(),
      builder: (_, snapshot) {
        final events = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.readOnly) ...[
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Event Title'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                    ),
                  ),
                  FilledButton(
                    onPressed: _pickDate,
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _addEvent,
                child: const Text('Add Event'),
              ),
              const Divider(height: 24),
            ] else ...[
              const Text('Events (read-only view)'),
              const Divider(height: 24),
            ],
            ...events.map(
              (e) => ListTile(
                title: Text(e.title),
                subtitle: Text(DateFormat('dd MMM yyyy').format(e.date)),
                trailing: const Icon(Icons.image),
              ),
            ),
            const ListTile(
              title: Text('Upload event photo/document'),
              subtitle: Text('Enforce max 100KB in storage upload policy'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _addEvent() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    await ref.read(repoProvider).addEvent(title: title, date: _selectedDate);
    _title.clear();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event added')));
    }
  }
}

class BirthdayTab extends ConsumerWidget {
  const BirthdayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<FamilyHead>>(
      future: ref.read(repoProvider).getFamilyHeads(),
      builder: (_, snapshot) {
        final heads = snapshot.data ?? [];
        final now = DateTime.now();
        final upcoming = heads.where((h) {
          final n = h.nakshatram;
          if (n == null || !n.contains('-')) return false;
          final parts = n.split('-');
          final dt = DateTime(
            now.year,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          final diff = dt
              .difference(DateTime(now.year, now.month, now.day))
              .inDays;
          return diff >= 0 && diff <= 7;
        }).toList();
        if (upcoming.isEmpty)
          return const Center(child: Text('No birthdays in next 7 days'));
        return ListView(
          children: upcoming
              .map(
                (u) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.cake)),
                  title: Text(u.name),
                  subtitle: const Text('Birthday in next 7 days'),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class EmployeesTab extends ConsumerStatefulWidget {
  const EmployeesTab({this.readOnly = false, super.key});

  final bool readOnly;

  @override
  ConsumerState<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends ConsumerState<EmployeesTab> {
  final _name = TextEditingController();
  final _designation = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmployeeEntry>>(
      future: ref.read(repoProvider).getEmployees(),
      builder: (_, snapshot) {
        final employees = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.readOnly) ...[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Employee Name'),
              ),
              TextField(
                controller: _designation,
                decoration: const InputDecoration(labelText: 'Designation'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _addEmployee,
                child: const Text('Add Employee'),
              ),
              const Divider(height: 24),
            ] else ...[
              const Text('Employee roster (read-only)'),
              const Divider(height: 24),
            ],
            ...employees.map(
              (e) => ListTile(
                title: Text(e.name),
                subtitle: Text(e.designation ?? 'Temple Employee'),
                trailing: const Text('Salary: Visible'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addEmployee() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(repoProvider)
        .addEmployee(
          name: name,
          designation: _designation.text.trim().isEmpty
              ? null
              : _designation.text.trim(),
        );
    _name.clear();
    _designation.clear();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Employee added')));
    }
  }
}

class TempleOpsTab extends StatefulWidget {
  const TempleOpsTab({this.readOnly = false, super.key});

  final bool readOnly;

  @override
  State<TempleOpsTab> createState() => _TempleOpsTabState();
}

class _TempleOpsTabState extends State<TempleOpsTab> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final List<Map<String, String>> _operations = [];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!widget.readOnly) ...[
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Operation Title'),
          ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes / Details'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _addOperation,
            child: const Text('Add Temple Operation'),
          ),
          const Divider(height: 24),
        ] else ...[
          const Text('Temple operations (read-only)'),
          const Divider(height: 24),
        ],
        ..._operations.map(
          (op) => ListTile(
            leading: const Icon(Icons.build_circle_outlined),
            title: Text(op['title'] ?? ''),
            subtitle: Text(op['notes'] ?? ''),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.electric_bolt),
          title: Text('Electricity Bill'),
          subtitle: Text(
            'Bill number and due date fields - add temple_charges table',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.water_drop),
          title: Text('Water Charges'),
          subtitle: Text('Reference number and monthly dues'),
        ),
        const ListTile(
          leading: Icon(Icons.meeting_room),
          title: Text('Hall Vacancy & Booking'),
          subtitle: Text('Add hall_bookings table with advance amount'),
        ),
      ],
    );
  }

  void _addOperation() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _operations.add({
        'title': title,
        'notes': _notes.text.trim().isEmpty ? 'No details' : _notes.text.trim(),
      });
      _title.clear();
      _notes.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Temple operation added')));
  }
}
