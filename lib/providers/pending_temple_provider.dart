import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/temple_models.dart';
import '../supabase/temple_repository.dart';

/// Temple chosen before / during login (persisted until sign-out).
final pendingTempleProvider = NotifierProvider<PendingTempleNotifier, Temple?>(
  () => PendingTempleNotifier(),
);

class PendingTempleNotifier extends Notifier<Temple?> {
  late final TempleRepository _repo;

  @override
  Temple? build() {
    _repo = ref.read(repoProvider);
    return null;
  }

  Future<void> syncFromTempleList(List<Temple> temples) async {
    await _repo.loadSelectedTemple();
    final savedId = _repo.selectedTempleId;
    if (savedId != null) {
      for (final t in temples) {
        if (t.id == savedId) {
          state = t;
          return;
        }
      }
    }
    if (temples.length == 1) {
      await select(temples.first);
    }
  }

  Future<void> select(Temple temple) async {
    await _repo.setSelectedTemple(temple.id);
    state = temple;
  }

  void setTemple(Temple temple) {
    state = temple;
  }

  void clear() {
    state = null;
  }
}
