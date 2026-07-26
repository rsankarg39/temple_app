import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/temple_models.dart';
import '../providers/pending_temple_provider.dart';
import '../supabase/temple_repository.dart';

/// Shared layout for login, MPIN, and password-reset screens with temple context.
class TempleAuthScaffold extends ConsumerWidget {
  const TempleAuthScaffold({
    required this.title,
    required this.body,
    this.bottom,
    this.actions,
    this.headerBelowBanner,
    super.key,
  });

  final String title;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;
  final Widget? headerBelowBanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTempleProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: bottom,
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TempleContextBanner(temple: pending),
            ?headerBelowBanner,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _TempleContextBanner extends StatelessWidget {
  const _TempleContextBanner({required this.temple});

  final Temple? temple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = temple?.name ?? 'Select a temple below';

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.temple_hindu_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Signing in to',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Temple dropdown used on login / register (updates banner everywhere).
class TemplePickerField extends ConsumerWidget {
  const TemplePickerField({
    required this.temples,
    required this.selectedId,
    required this.onChanged,
    this.loading = false,
    super.key,
  });

  final List<Temple> temples;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: 'Temple *',
        helperText: 'Required — all data is scoped to this temple',
      ),
      items: temples
          .map(
            (t) => DropdownMenuItem<String>(
              value: t.id,
              child: Text(
                t.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (id) async {
        onChanged(id);
        if (id == null) return;
        final temple = temples.where((t) => t.id == id).firstOrNull;
        if (temple != null) {
          await ref.read(pendingTempleProvider.notifier).select(temple);
        }
      },
    );
  }
}

/// Scrollable body with consistent padding and keyboard inset.
class AuthScrollBody extends StatelessWidget {
  const AuthScrollBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottom),
      children: children,
    );
  }
}

/// Ensures pending temple is loaded when entering post-login auth steps.
Future<void> ensurePendingTempleLoaded(WidgetRef ref) async {
  if (ref.read(pendingTempleProvider) != null) return;
  await ref.read(repoProvider).loadSelectedTemple();
  final id = ref.read(repoProvider).selectedTempleId;
  if (id == null) return;
  try {
    final temples = await ref.read(repoProvider).getActiveTemples();
    final match = temples.where((t) => t.id == id).firstOrNull;
    if (match != null) {
      ref.read(pendingTempleProvider.notifier).setTemple(match);
    }
  } catch (_) {}
}
