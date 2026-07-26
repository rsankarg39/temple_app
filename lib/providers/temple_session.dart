import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/temple_models.dart';
import '../supabase/temple_repository.dart';
import '../widgets/temple_auth_scaffold.dart';

/// Tracks the active temple session (selected temple + role).
class TempleSession {
  const TempleSession({
    required this.membership,
  });

  final TempleMembership membership;

  Temple get temple => membership.temple;
  AppRole get role => membership.role;
}

final templeSessionProvider = NotifierProvider<TempleSessionNotifier, TempleSession?>(
  () => TempleSessionNotifier(),
);

class TempleSessionNotifier extends Notifier<TempleSession?> {
  late final TempleRepository _repo;

  @override
  TempleSession? build() {
    _repo = ref.read(repoProvider);
    return null;
  }

  Future<List<TempleMembership>> loadUserTemples() => _repo.getUserTemples();

  Future<void> selectMembership(TempleMembership membership) async {
    await _repo.setSelectedTemple(membership.temple.id);
    state = TempleSession(membership: membership);
  }

  Future<bool> restoreOrPrompt() async {
    await _repo.loadSelectedTemple();
    final memberships = await _repo.getUserTemples();
    if (memberships.isEmpty) return false;

    if (memberships.length == 1) {
      await selectMembership(memberships.first);
      return true;
    }

    final savedId = _repo.selectedTempleId;
    if (savedId != null) {
      final match = memberships.where((m) => m.temple.id == savedId);
      if (match.isNotEmpty) {
        await selectMembership(match.first);
        return true;
      }
    }

    final primary = memberships.where((m) => m.isPrimary);
    if (primary.isNotEmpty) {
      await selectMembership(primary.first);
      return true;
    }

    return false;
  }

  void clear() {
    state = null;
  }
}

/// Gate that ensures a temple is selected before showing the home dashboard.
class TempleGate extends ConsumerStatefulWidget {
  const TempleGate({required this.onReady, super.key});

  final Widget onReady;

  @override
  ConsumerState<TempleGate> createState() => _TempleGateState();
}

class _TempleGateState extends ConsumerState<TempleGate> {
  bool _loading = true;
  bool _needsSelection = false;
  List<TempleMembership> _memberships = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final notifier = ref.read(templeSessionProvider.notifier);
    final restored = await notifier.restoreOrPrompt();
    if (!mounted) return;
    if (restored && ref.read(templeSessionProvider) != null) {
      setState(() => _loading = false);
      return;
    }

    final memberships = await notifier.loadUserTemples();
    if (!mounted) return;
    if (memberships.isEmpty) {
      setState(() {
        _loading = false;
        _needsSelection = true;
        _memberships = [];
      });
      return;
    }
    if (memberships.length == 1) {
      await notifier.selectMembership(memberships.first);
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = false;
      _needsSelection = true;
      _memberships = memberships;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const TempleAuthScaffold(
        title: 'Loading',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = ref.watch(templeSessionProvider);
    if (session != null) {
      return widget.onReady;
    }

    if (_needsSelection) {
      return TempleSelectorPage(
        memberships: _memberships,
        onSelected: () => setState(() {}),
      );
    }

    return TempleAuthScaffold(
      title: 'No Temple Access',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.temple_hindu_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Your account is not linked to any temple yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ref.read(repoProvider).signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TempleSelectorPage extends ConsumerWidget {
  const TempleSelectorPage({
    required this.memberships,
    this.onSelected,
    super.key,
  });

  final List<TempleMembership> memberships;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TempleAuthScaffold(
      title: 'Select Temple',
      actions: [
        IconButton(
          onPressed: () => ref.read(repoProvider).signOut(),
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
        ),
      ],
      body: AuthScrollBody(
        children: [
          Text(
            'Choose your primary temple',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            memberships.length > 1
                ? 'You belong to multiple temples. Select one to continue. You can switch later from the dashboard.'
                : 'Select a temple to continue.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 16),
          ...memberships.map(
            (m) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    m.temple.name.isNotEmpty
                        ? m.temple.name[0].toUpperCase()
                        : 'T',
                  ),
                ),
                title: Text(
                  m.temple.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (m.temple.city != null) m.temple.city!,
                    'Role: ${m.role.name.toUpperCase()}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: m.isPrimary
                    ? Chip(
                        label: Text(
                          'Primary',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  await ref
                      .read(templeSessionProvider.notifier)
                      .selectMembership(m);
                  onSelected?.call();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTempleSwitcher(BuildContext context, WidgetRef ref) async {
  final memberships =
      await ref.read(templeSessionProvider.notifier).loadUserTemples();
  if (!context.mounted) return;
  if (memberships.length <= 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You belong to only one temple')),
    );
    return;
  }

  final selected = await showModalBottomSheet<TempleMembership>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Switch Temple',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ...memberships.map(
            (m) => ListTile(
              leading: const Icon(Icons.temple_hindu_outlined),
              title: Text(m.temple.name),
              subtitle: Text('${m.role.name.toUpperCase()}'),
              onTap: () => Navigator.pop(ctx, m),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (selected != null) {
    await ref.read(templeSessionProvider.notifier).selectMembership(selected);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${selected.temple.name}')),
      );
      // Force dashboard rebuild with new temple role
      ref.invalidate(repoProvider);
    }
  }
}

Future<void> showPaymentHistoryOnLogin(
  BuildContext context,
  WidgetRef ref,
) async {
  final repo = ref.read(repoProvider);
  final role = await repo.getCurrentRole();
  if (role != AppRole.user) return;

  final fullName = await repo.getCurrentUserFullName();
  final uid = repo.client.auth.currentUser?.id;
  if (fullName == null) return;

  final payments = await repo.getPaymentsForUser(
    fullName: fullName,
    userId: uid,
  );
  if (!context.mounted || payments.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your Payment History'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: payments.length,
          separatorBuilder: (_, __) => const Divider(height: 8),
          itemBuilder: (_, i) {
            final p = payments[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Rs.${p.amount.toStringAsFixed(2)}'),
              subtitle: Text(p.purpose ?? 'General donation'),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
