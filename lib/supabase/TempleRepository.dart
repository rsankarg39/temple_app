import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppRole { admin, committee, user }

AppRole roleFromString(String value) {
  switch (value.toLowerCase()) {
    case 'admin':
      return AppRole.admin;
    case 'committee':
      return AppRole.committee;
    default:
      return AppRole.user;
  }
}

final repoProvider = Provider(
  (_) => TempleRepository(Supabase.instance.client),
);

class TempleRepository {
  final SupabaseClient client;
  TempleRepository(this.client);

  // ---------- AUTH ----------
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? mpin,
    String? gender,
    String? kulam,
    String? maritalStatus,
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
      },
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ---------- MPIN ----------
  Future<bool> hasMpin() async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final data = await client
        .from('profiles')
        .select('mpin')
        .eq('id', user.id)
        .maybeSingle();
    return data?['mpin'] != null;
  }

  Future<void> setMpin(String mpin) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.from('profiles').update({'mpin': mpin}).eq('id', user.id);
  }

  Future<bool> verifyMpin(String mpin) async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final data = await client
        .from('profiles')
        .select('mpin')
        .eq('id', user.id)
        .maybeSingle();
    return data?['mpin'] == mpin;
  }

  Future<void> markPasswordLoginBypass() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('password_bypass', true);
  }

  Future<bool> consumePasswordLoginBypass() async {
    final prefs = await SharedPreferences.getInstance();
    final bypass = prefs.getBool('password_bypass') ?? false;
    if (bypass) {
      await prefs.remove('password_bypass');
    }
    return bypass;
  }

  // ---------- ROLES ----------
  Future<AppRole> getCurrentRole() async {
    final user = client.auth.currentUser;
    if (user == null) return AppRole.user;
    final data = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return roleFromString(data?['role'] ?? 'user');
  }

  Future<List<UserProfileSummary>> getAllProfiles() async {
    final data = await client.from('profiles').select();
    return (data as List)
        .map((row) => UserProfileSummary.fromJson(row))
        .toList();
  }

  Future<List<UserProfileSummary>> getProfilesByRole(String role) async {
    final data = await client.from('profiles').select().eq('role', role);
    return (data as List)
        .map((row) => UserProfileSummary.fromJson(row))
        .toList();
  }

  Future<List<UserProfileSummary>> getAdmins() async {
    return getProfilesByRole('admin');
  }

  Future<void> updateUserRole({
    required String profileId,
    required AppRole role,
    required String fullName,
  }) async {
    await client
        .from('profiles')
        .update({'role': role.name})
        .eq('id', profileId);
  }

  Future<void> ensureCurrentProfileExists() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final existing = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (existing == null) {
      await client.from('profiles').insert({
        'id': user.id,
        'email': user.email,
        'full_name':
            user.userMetadata?['full_name'] ??
            (user.email?.split('@').first ?? 'User'),
        'phone': user.userMetadata?['phone'],
        'mpin': user.userMetadata?['mpin'],
        'gender': user.userMetadata?['gender'],
        'kulam': user.userMetadata?['kulam'],
        'marital_status': user.userMetadata?['marital_status'],
        'business': user.userMetadata?['business'],
        'photo_url': user.userMetadata?['photo_url'],
        'role': 'user',
      });
    }
  }

  // ---------- FAMILY HEADS ----------
  Future<List<FamilyHead>> getFamilyHeads() async {
    final data = await client.from('familyheads').select();
    return (data as List).map((row) => FamilyHead.fromJson(row)).toList();
  }

  Future<void> addFamilyHead({
    required String name,
    required String phone,
    String? nakshatram,
  }) async {
    await client.from('familyheads').insert({
      'name': name,
      'phone': phone,
      'nakshatram': nakshatram,
    });
  }

  // ---------- COMMITTEE ----------
  Future<List<CommitteeMember>> getCommitteeMembers() async {
    final data = await client.from('committee').select();
    return (data as List).map((row) => CommitteeMember.fromJson(row)).toList();
  }

  Future<List<EmployeeEntry>> getEmployees() async {
    final data = await client.from('employees').select();
    return (data as List).map((row) => EmployeeEntry.fromJson(row)).toList();
  }

  Future<void> deleteEmployee(int id) async {
    await client.from('employees').delete().eq('id', id);
  }

  // ---------- PAYMENTS ----------
  Future<List<PaymentEntry>> getPayments() async {
    final data = await client.from('payments').select();
    return (data as List).map((row) => PaymentEntry.fromJson(row)).toList();
  }

  Future<void> addPayment({
    required String payer,
    required double amount,
    String? purpose,
  }) async {
    await client.from('payments').insert({
      'payer': payer,
      'amount': amount,
      'purpose': purpose,
    });
  }

  // ---------- POOJAS ----------
  Future<List<PoojaEntry>> getPoojas() async {
    final data = await client.from('poojas').select();
    return (data as List).map((row) => PoojaEntry.fromJson(row)).toList();
  }
}

// ---------- MODELS ----------
class UserProfileSummary {
  final String id;
  final String fullName;
  final String? email;
  final String role;

  UserProfileSummary({
    required this.id,
    required this.fullName,
    this.email,
    required this.role,
  });

  factory UserProfileSummary.fromJson(Map<String, dynamic> json) {
    return UserProfileSummary(
      id: json['id'] as String,
      fullName: json['fullName'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'user',
    );
  }
}

class FamilyHead {
  final int id;
  final String name;
  final String phone;
  final String? nakshatram;

  FamilyHead({
    required this.id,
    required this.name,
    required this.phone,
    this.nakshatram,
  });

  factory FamilyHead.fromJson(Map<String, dynamic> json) {
    return FamilyHead(
      id: json['id'] as int,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      nakshatram: json['nakshatram'],
    );
  }
}

class CommitteeMember {
  final int id;
  final String name;
  final String? role;

  CommitteeMember({required this.id, required this.name, this.role});

  factory CommitteeMember.fromJson(Map<String, dynamic> json) {
    return CommitteeMember(
      id: json['id'] as int,
      name: json['name'] ?? '',
      role: json['role'],
    );
  }
}

class EmployeeEntry {
  final int id;
  final String name;
  final String? designation;

  EmployeeEntry({required this.id, required this.name, this.designation});

  factory EmployeeEntry.fromJson(Map<String, dynamic> json) {
    return EmployeeEntry(
      id: json['id'] as int,
      name: json['name'] ?? '',
      designation: json['designation'],
    );
  }
}

class PaymentEntry {
  final int id;
  final String payer;
  final double amount;
  final String? purpose;

  PaymentEntry({
    required this.id,
    required this.payer,
    required this.amount,
    this.purpose,
  });

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      id: json['id'] as int,
      payer: json['payer'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      purpose: json['purpose'],
    );
  }
}

class PoojaEntry {
  final int id;
  final String name;
  final String? description;

  PoojaEntry({required this.id, required this.name, this.description});

  factory PoojaEntry.fromJson(Map<String, dynamic> json) {
    return PoojaEntry(
      id: json['id'] as int,
      name: json['name'] ?? '',
      description: json['description'],
    );
  }
}
