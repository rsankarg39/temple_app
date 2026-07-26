# Temple Book App (Flutter + Supabase)

Cross-platform mobile app for Android and iOS temple maintenance with role-based access.

## Current implementation

- Role-aware app navigation for `Admin`, `Committee`, `User`
- CRUD-ready Supabase repository for your existing tables:
  - `familyheads`
  - `committeemembers`
  - `employees`
  - `events`
  - `payments`
  - `poojas`
- Family head privacy masking for user role
- UPI payment launch + payment history
- Upcoming birthdays (next 7 days)
- Committee, employee, pooja and event tabs
- Temple operations placeholders (charges, hall booking)
- Receipt sharing via social/WhatsApp using native share sheet

## Run the app

### Option A (easy): plain `flutter run`

1. Open `lib/supabase_config.dart`
2. Set:
   - `SupabaseConfig.url`
   - `SupabaseConfig.anonKey`
3. Run:

```bash
flutter pub get
flutter run
```

### Option B (more secure): runtime define values

```bash
flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Use Option B for CI/CD and production builds.

## Important schema note

Your provided schema is a good start, but some requested features need additional tables/columns.
Recommended additions:

- `profiles` table with:
  - gender, age, dob, nakshatram, kulam_subdivision, address
  - is_family_head, family_head_id (nullable when head)
  - other_temple_association, marital_status, email, phone, social_links
  - work_business_info, photo_url
- `contributions` table for historical member contributions
- `temple_accounts` table for default UPI/account config (admin-managed)
- `employee_payments` table for salary history
- `temple_charges` table for electricity/water bill number and due details
- `hall_bookings` table with vacancy status, advance amount, booking user
- `pooja_bookings` table linked to pooja/payment
- `event_media` table (photo/doc url, size) with <=100KB validation in app + storage policy

## Access control recommendation

Use Supabase Auth + `profiles.role` and apply Row Level Security policies:

- Admin: full access
- Committee: operations + financial view
- User: read-only on permitted data and own payment history

## Authentication added in app

- Email/password login and registration
- MPIN setup for first login (4-digit)
- MPIN verification on subsequent sessions
- SQL migration file for MPIN:
  - `supabase/migrations/20260423_auth_mpin_setup.sql`
