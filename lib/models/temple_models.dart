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

class Temple {
  Temple({
    required this.id,
    required this.name,
    this.slug,
    this.address,
    this.city,
    this.upiId,
  });

  final String id;
  final String name;
  final String? slug;
  final String? address;
  final String? city;
  final String? upiId;

  factory Temple.fromMap(Map<String, dynamic> map) => Temple(
        id: map['id'] as String,
        name: map['name'] as String,
        slug: map['slug'] as String?,
        address: map['address'] as String?,
        city: map['city'] as String?,
        upiId: map['upi_id'] as String?,
      );
}

class TempleMembership {
  TempleMembership({
    required this.temple,
    required this.role,
    this.isPrimary = false,
  });

  final Temple temple;
  final AppRole role;
  final bool isPrimary;

  factory TempleMembership.fromMap(Map<String, dynamic> map) {
    final templeData = map['temples'] as Map<String, dynamic>? ?? map;
    return TempleMembership(
      temple: Temple.fromMap(templeData),
      role: roleFromString(map['role'] as String? ?? 'user'),
      isPrimary: map['is_primary'] as bool? ?? false,
    );
  }
}

class UserProfileSummary {
  UserProfileSummary({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
  });

  final String id;
  final String fullName;
  final String role;
  final String? email;

  factory UserProfileSummary.fromMap(Map<String, dynamic> map) =>
      UserProfileSummary(
        id: map['id'] as String,
        fullName: map['full_name'] as String? ?? 'Unnamed',
        role: map['role'] as String? ?? 'user',
        email: map['email'] as String?,
      );
}

class FamilyHead {
  FamilyHead({
    required this.id,
    required this.name,
    required this.phone,
    this.nakshatram,
  });

  final int id;
  final String name;
  final String phone;
  final String? nakshatram;

  factory FamilyHead.fromMap(Map<String, dynamic> map) => FamilyHead(
        id: map['id'] as int,
        name: map['name'] as String,
        phone: map['phone'] as String,
        nakshatram: map['nakshatram'] as String?,
      );
}

class CommitteeMember {
  CommitteeMember({required this.id, required this.name, this.role});
  final int id;
  final String name;
  final String? role;

  factory CommitteeMember.fromMap(Map<String, dynamic> map) => CommitteeMember(
        id: map['id'] as int,
        name: map['name'] as String,
        role: map['role'] as String?,
      );
}

class EmployeeEntry {
  EmployeeEntry({required this.id, required this.name, this.designation});
  final int id;
  final String name;
  final String? designation;

  factory EmployeeEntry.fromMap(Map<String, dynamic> map) => EmployeeEntry(
        id: map['id'] as int,
        name: map['name'] as String,
        designation: map['designation'] as String?,
      );
}

class EventEntry {
  EventEntry({required this.id, required this.title, required this.date});
  final int id;
  final String title;
  final DateTime date;

  factory EventEntry.fromMap(Map<String, dynamic> map) => EventEntry(
        id: map['id'] as int,
        title: map['title'] as String,
        date: DateTime.parse(map['date'] as String),
      );
}

class PaymentEntry {
  PaymentEntry({
    required this.id,
    required this.payer,
    required this.amount,
    this.purpose,
    this.paidAt,
  });
  final int id;
  final String payer;
  final double amount;
  final String? purpose;
  final DateTime? paidAt;

  factory PaymentEntry.fromMap(Map<String, dynamic> map) => PaymentEntry(
        id: map['id'] as int,
        payer: map['payer'] as String,
        amount: (map['amount'] as num).toDouble(),
        purpose: map['purpose'] as String?,
        paidAt: map['paid_at'] != null
            ? DateTime.tryParse(map['paid_at'] as String)
            : null,
      );
}

class PoojaEntry {
  PoojaEntry({
    required this.id,
    required this.name,
    this.description,
    this.poojaDate,
    this.scheduledTime,
    this.category,
  });
  final int id;
  final String name;
  final String? description;
  final DateTime? poojaDate;
  final String? scheduledTime;
  final String? category;

  bool get isPast {
    if (poojaDate == null) return false;
    final today = DateTime.now();
    final d = DateTime(poojaDate!.year, poojaDate!.month, poojaDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isBefore(t);
  }

  bool get isCurrentOrUpcoming => !isPast;

  factory PoojaEntry.fromMap(Map<String, dynamic> map) => PoojaEntry(
        id: map['id'] as int,
        name: map['name'] as String,
        description: map['description'] as String?,
        poojaDate: map['pooja_date'] != null
            ? DateTime.tryParse(map['pooja_date'] as String)
            : null,
        scheduledTime: map['scheduled_time'] as String?,
        category: map['category'] as String?,
      );
}

String maskPhone(String phone) {
  if (phone.length < 4) return '****';
  return '${phone.substring(0, 2)}******${phone.substring(phone.length - 2)}';
}
