import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/temple_models.dart';

const defaultTempleId = '00000000-0000-0000-0000-000000000001';
const _selectedTempleKey = 'selected_temple_id';

final repoProvider = Provider(
  (ref) => TempleRepository(Supabase.instance.client),
);

class TempleRepository {
  TempleRepository(this.client);

  final SupabaseClient client;
  String? _selectedTempleId;

  String? get selectedTempleId => _selectedTempleId;

  Future<void> loadSelectedTemple() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedTempleId = prefs.getString(_selectedTempleKey);
  }

  Future<void> setSelectedTemple(String templeId) async {
    _selectedTempleId = templeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedTempleKey, templeId);
  }

  Future<void> clearSelectedTemple() async {
    _selectedTempleId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedTempleKey);
  }

  String _requireTempleId() {
    final id = _selectedTempleId;
    if (id == null || id.isEmpty) {
      throw StateError('No temple selected');
    }
    return id;
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sends a password reset link to [email]. User completes reset via email.
  Future<void> sendPasswordResetEmail(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  /// Sets a new password after the user opens the reset link from email.
  Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    required String templeId,
    String? phone,
    String? mpin,
    required String gender,
    required String kulam,
    required String maritalStatus,
    String? business,
    String? photoUrl,
  }) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': name,
        'phone': phone,
        'mpin': mpin,
        'gender': gender,
        'kulam': kulam,
        'marital_status': maritalStatus,
        'business': business,
        'photo_url': photoUrl,
        'temple_id': templeId,
      },
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
    // Keep selected temple in prefs so login screen shows the same temple.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('password_login_bypass');
  }

  Future<List<Temple>> getActiveTemples() async {
    final rows = await client
        .from('temples')
        .select('id, name, slug, address, city, upi_id')
        .eq('is_active', true)
        .order('name');
    return (rows as List).map((e) => Temple.fromMap(e)).toList();
  }

  Future<List<TempleMembership>> getUserTemples() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await client
        .from('user_temples')
        .select(
          'role, is_primary, temples(id, name, slug, address, city, upi_id)',
        )
        .eq('profile_id', uid)
        .order('is_primary', ascending: false);
    return (rows as List).map((e) => TempleMembership.fromMap(e)).toList();
  }

  Future<AppRole> getCurrentRole() async {
    final uid = client.auth.currentUser?.id;
    final templeId = _selectedTempleId;
    if (uid == null || templeId == null) return AppRole.user;

    final row = await client
        .from('user_temples')
        .select('role')
        .eq('profile_id', uid)
        .eq('temple_id', templeId)
        .maybeSingle();
    if (row != null) {
      return roleFromString(row['role'] as String? ?? 'user');
    }

    // Fallback for deployments without user_temples migration yet
    final profile = await client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return roleFromString(profile?['role'] as String? ?? 'user');
  }

  Future<Temple?> getSelectedTemple() async {
    final templeId = _selectedTempleId;
    if (templeId == null) return null;
    final row = await client
        .from('temples')
        .select('id, name, slug, address, city, upi_id')
        .eq('id', templeId)
        .maybeSingle();
    return row == null ? null : Temple.fromMap(row);
  }

  Future<String?> getCurrentUserFullName() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await client
        .from('profiles')
        .select('full_name')
        .eq('id', uid)
        .maybeSingle();
    return row?['full_name'] as String?;
  }

  Future<bool> hasMpin() async {
    final result = await client.rpc('has_user_mpin');
    return result == true;
  }

  Future<void> ensureCurrentProfileExists() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final exists = await client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (exists == null) {
      await client.from('profiles').insert({
        'id': user.id,
        'full_name':
            user.userMetadata?['full_name'] ??
            (user.email?.split('@').first ?? 'User'),
        'email': user.email,
        'phone': user.userMetadata?['phone'],
        'role': 'user',
        'is_family_head': true,
      });
    }

    final templeId =
        user.userMetadata?['temple_id'] as String? ?? defaultTempleId;
    final membership = await client
        .from('user_temples')
        .select('id')
        .eq('profile_id', user.id)
        .eq('temple_id', templeId)
        .maybeSingle();
    if (membership == null) {
      try {
        await client.from('user_temples').insert({
          'profile_id': user.id,
          'temple_id': templeId,
          'role': 'user',
          'is_primary': true,
        });
      } catch (_) {
        // Table may not exist on older deployments.
      }
    }
  }

  Future<void> markPasswordLoginBypass() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('password_login_bypass', true);
  }

  Future<bool> consumePasswordLoginBypass() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('password_login_bypass') ?? false;
    if (value) {
      await prefs.setBool('password_login_bypass', false);
    }
    return value;
  }

  Future<void> setMpin(String mpin) async {
    await client.rpc('set_user_mpin', params: {'p_mpin': mpin});
  }

  Future<bool> verifyMpin(String mpin) async {
    final result = await client.rpc(
      'verify_user_mpin',
      params: {'p_mpin': mpin},
    );
    return result == true;
  }

  Future<List<UserProfileSummary>> getAllProfiles() async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('user_temples')
        .select('role, profiles(id, full_name, email)')
        .eq('temple_id', templeId)
        .order('joined_at', ascending: false);
    return (rows as List).map((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      return UserProfileSummary(
        id: profile['id'] as String,
        fullName: profile['full_name'] as String? ?? 'Unnamed',
        role: e['role'] as String? ?? 'user',
        email: profile['email'] as String?,
      );
    }).toList();
  }

  Future<List<UserProfileSummary>> getProfilesByRole(String role) async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('user_temples')
        .select('role, profiles(id, full_name, email)')
        .eq('temple_id', templeId)
        .eq('role', role)
        .order('joined_at', ascending: false);
    return (rows as List).map((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      return UserProfileSummary(
        id: profile['id'] as String,
        fullName: profile['full_name'] as String? ?? 'Unnamed',
        role: e['role'] as String? ?? 'user',
        email: profile['email'] as String?,
      );
    }).toList();
  }

  Future<void> updateUserRole({
    required String profileId,
    required AppRole role,
    required String fullName,
  }) async {
    final templeId = _requireTempleId();
    await client
        .from('user_temples')
        .update({'role': role.name})
        .eq('profile_id', profileId)
        .eq('temple_id', templeId);

    // Keep global profile role in sync for legacy helpers
    await client
        .from('profiles')
        .update({'role': role.name})
        .eq('id', profileId);

    try {
      if (role == AppRole.committee) {
        final rows = await client
            .from('committeemembers')
            .select('id')
            .eq('profile_id', profileId)
            .eq('temple_id', templeId)
            .limit(1);
        if ((rows as List).isEmpty) {
          await client.from('committeemembers').insert({
            'name': fullName,
            'role': 'Member',
            'profile_id': profileId,
            'temple_id': templeId,
          });
        }
      } else {
        await client
            .from('committeemembers')
            .delete()
            .eq('profile_id', profileId)
            .eq('temple_id', templeId);
      }
    } catch (_) {}
  }

  Future<List<FamilyHead>> getFamilyHeads() async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('familyheads')
        .select()
        .eq('temple_id', templeId);
    return (rows as List).map((e) => FamilyHead.fromMap(e)).toList();
  }

  Future<void> addFamilyHead({
    required String name,
    required String phone,
    String? nakshatram,
  }) async {
    final templeId = _requireTempleId();
    await client.from('familyheads').insert({
      'name': name,
      'phone': phone,
      'nakshatram': nakshatram,
      'temple_id': templeId,
    });
  }

  Future<List<CommitteeMember>> getCommitteeMembers() async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('committeemembers')
        .select()
        .eq('temple_id', templeId);
    return (rows as List).map((e) => CommitteeMember.fromMap(e)).toList();
  }

  Future<List<PaymentEntry>> getPayments() async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('payments')
        .select()
        .eq('temple_id', templeId)
        .order('id', ascending: false);
    return (rows as List).map((e) => PaymentEntry.fromMap(e)).toList();
  }

  Future<List<PaymentEntry>> getMyPayments() async {
    final templeId = _requireTempleId();
    final uid = client.auth.currentUser?.id;
    final fullName = await getCurrentUserFullName();
    if (uid == null && fullName == null) return [];

    final rows = await client
        .from('payments')
        .select()
        .eq('temple_id', templeId)
        .order('id', ascending: false);

    return (rows as List)
        .where((e) {
          final map = e as Map<String, dynamic>;
          if (uid != null && map['payer_user_id'] == uid) return true;
          if (fullName != null) {
            final payer = map['payer'] as String? ?? '';
            return payer.toLowerCase() == fullName.toLowerCase();
          }
          return false;
        })
        .map((e) => PaymentEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PaymentEntry>> getPaymentsForUser({
    required String fullName,
    String? userId,
  }) async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('payments')
        .select()
        .eq('temple_id', templeId)
        .order('id', ascending: false);
    return (rows as List)
        .where((e) {
          final map = e as Map<String, dynamic>;
          if (userId != null && map['payer_user_id'] == userId) return true;
          final payer = map['payer'] as String? ?? '';
          return payer.toLowerCase() == fullName.toLowerCase();
        })
        .map((e) => PaymentEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addPayment({
    required String payer,
    required double amount,
    String? purpose,
  }) async {
    final templeId = _requireTempleId();
    await client.from('payments').insert({
      'payer': payer,
      'amount': amount,
      'purpose': purpose,
      'payer_user_id': client.auth.currentUser?.id,
      'temple_id': templeId,
    });
  }

  Future<void> updatePayment({
    required int id,
    required String payer,
    required double amount,
    String? purpose,
  }) async {
    final templeId = _requireTempleId();
    await client
        .from('payments')
        .update({'payer': payer, 'amount': amount, 'purpose': purpose})
        .eq('id', id)
        .eq('temple_id', templeId);
  }

  Future<String> getTempleUpiId() async {
    final temple = await getSelectedTemple();
    return temple?.upiId ?? 'temple@upi';
  }

  Future<void> addPooja({
    required String name,
    String? description,
    DateTime? poojaDate,
    String? category,
  }) async {
    final templeId = _requireTempleId();
    await client.from('poojas').insert({
      'name': name,
      'description': description,
      'pooja_date': poojaDate?.toIso8601String().split('T').first,
      'category': category ?? 'daily',
      'temple_id': templeId,
    });
  }

  Future<List<PoojaEntry>> getPoojas({bool? upcomingOnly, bool? pastOnly}) async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('poojas')
        .select()
        .eq('temple_id', templeId)
        .order('pooja_date', ascending: true);
    var poojas = (rows as List).map((e) => PoojaEntry.fromMap(e)).toList();
    if (upcomingOnly == true) {
      poojas = poojas.where((p) => p.isCurrentOrUpcoming).toList();
    } else if (pastOnly == true) {
      poojas = poojas.where((p) => p.isPast).toList();
    }
    return poojas;
  }

  Future<void> addEvent({required String title, required DateTime date}) async {
    final templeId = _requireTempleId();
    await client.from('events').insert({
      'title': title,
      'date': date.toIso8601String(),
      'temple_id': templeId,
    });
  }

  Future<void> addEmployee({required String name, String? designation}) async {
    final templeId = _requireTempleId();
    await client.from('employees').insert({
      'name': name,
      'designation': designation,
      'temple_id': templeId,
    });
  }

  Future<List<EventEntry>> getEvents() async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('events')
        .select()
        .eq('temple_id', templeId)
        .order('date', ascending: false);
    return (rows as List).map((e) => EventEntry.fromMap(e)).toList();
  }

  Future<List<EmployeeEntry>> getEmployees() async {
    final templeId = _requireTempleId();
    final rows = await client
        .from('employees')
        .select()
        .eq('temple_id', templeId);
    return (rows as List).map((e) => EmployeeEntry.fromMap(e)).toList();
  }
}
