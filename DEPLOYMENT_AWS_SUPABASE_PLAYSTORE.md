# Temple Book App — Deploy on Supabase (free), AWS (free web hosting), & Google Play

This guide matches **your current Flutter app** (Supabase backend, no custom Node server required).

| Component | Recommended free option | Purpose |
|-----------|-------------------------|---------|
| Database + Auth + API | **Supabase Free** | Backend for the mobile app |
| Admin / optional web | **AWS S3 + CloudFront** (free tier) | Host Flutter **web** build only |
| Android app | **Google Play Console** | Distribute APK/AAB to users |

> **Note:** The Android app talks **directly to Supabase**. You do **not** need AWS to run the database or auth for Play Store release. AWS is optional if you want a **website** version.

---

## Part 1 — Supabase (free tier) — backend for the app

### 1.1 Create Supabase project

1. Go to [https://supabase.com](https://supabase.com) and sign up (free).
2. **New project** → choose organization → set:
   - **Name:** `temple-book`
   - **Database password:** save this securely
   - **Region:** closest to your users (e.g. `South Asia (Mumbai)` for India)
3. Wait until the project status is **Active** (~2 minutes).

### 1.2 Run database migrations

1. In Supabase Dashboard → **SQL Editor** → **New query**.
2. Run each file **in order** (copy/paste full file → **Run**):
   - `supabase/migrations/20260423_temple_full_setup.sql`
   - `supabase/migrations/20260423_auth_mpin_setup.sql`
   - `supabase/migrations/20260530_multi_temple_setup.sql`
3. Confirm tables under **Table Editor**: `temples`, `user_temples`, `profiles`, `payments`, `poojas`, etc.

### 1.3 Auth & email settings

1. **Authentication** → **Providers** → enable **Email**.
2. **Authentication** → **URL configuration**:
   - **Site URL:** `https://your-project-ref.supabase.co` (or your web app URL later)
   - **Redirect URLs:** add:
     - `io.supabase.flutter://login-callback/`
     - `com.yourcompany.templebook://login-callback/` (use your final Android package name)
3. **Authentication** → **Email templates** → customize “Reset password” if needed.
4. For testing, you can disable “Confirm email” under **Sign In / Providers** → Email → **Confirm email** (turn off for faster testing; turn on for production).

### 1.4 Get API keys for the Flutter app

1. **Project Settings** → **API**.
2. Copy:
   - **Project URL** (e.g. `https://xxxxx.supabase.co`)
   - **anon public** key (safe to embed in the app with RLS enabled)

### 1.5 Point the app to Supabase (production)

**Do not commit production keys to Git.** Use `--dart-define`:

```powershell
cd "d:\Sankar Giri R\Project Start Up\temple_book_app"

flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Update `lib/supabase_config.dart` to read from environment (recommended pattern):

```dart
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_DEV_PROJECT.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_DEV_ANON_KEY',
  );
}
```

### 1.6 Seed temples (first-time)

In **SQL Editor**:

```sql
INSERT INTO public.temples (name, slug, city, upi_id, is_active)
VALUES ('Default Temple', 'default-temple', 'Your City', 'your-temple@upi', true)
ON CONFLICT (slug) DO NOTHING;
```

Add more temples as needed. Link users via `user_temples` or registration flow in the app.

### 1.7 Supabase free tier limits (awareness)

- 500 MB database, 1 GB file storage, 50k monthly active users (check current limits on supabase.com/pricing).
- Project **pauses** after 1 week of inactivity on free tier — open dashboard or upgrade to Pro to avoid pause.

---

## Part 2 — AWS (free tier) — optional web hosting only

Use this if you want users to open the app in a **browser**. The **Play Store app does not require AWS**.

### 2.1 Build Flutter web

```powershell
flutter build web --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Output: `build/web/`

### 2.2 Create S3 bucket (static website)

1. [AWS Console](https://console.aws.amazon.com) → create **Free tier** account.
2. **S3** → **Create bucket**:
   - Name: `temple-book-web` (globally unique)
   - Region: e.g. `ap-south-1` (Mumbai)
   - Uncheck “Block all public access” only if using static website (or use CloudFront OAC later)
3. **Properties** → **Static website hosting** → Enable → index: `index.html`
4. Upload all files from `build/web/` to the bucket root.

### 2.3 Bucket policy (public read for static site)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadGetObject",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::temple-book-web/*"
  }]
}
```

### 2.4 Optional: CloudFront (HTTPS + CDN)

1. **CloudFront** → Create distribution → origin = S3 website endpoint.
2. Default certificate `*.cloudfront.net` gives HTTPS URL.
3. Add CloudFront URL to Supabase **Redirect URLs**.

### 2.5 AWS free tier notes

- 12 months free tier for new accounts; S3/CloudFront have ongoing free allowances.
- **Do not** put database on free EC2 unless you self-host Supabase (complex). Use **Supabase cloud** instead.

### 2.6 Alternative: skip AWS entirely

- **Play Store only:** Supabase + Play Console is enough.
- **Cheaper web:** [Cloudflare Pages](https://pages.cloudflare.com) or [Netlify](https://www.netlify.com) free — upload `build/web`.

---

## Part 3 — Google Play Store launch

### 3.1 Prerequisites checklist

| Item | Status |
|------|--------|
| Google Play Developer account | **$25 one-time** registration fee |
| Unique package name (not `com.example.*`) | Required |
| Privacy policy URL (public HTTPS) | Required |
| App icon 512×512, feature graphic 1024×500 | Required |
| Phone screenshots (min 2) | Required |
| Release AAB signed with upload key | Required |
| Supabase production project + migrations | Required |

### 3.2 Change Android application ID

Edit `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    applicationId = "com.yourtemple.templebook"  // must be unique globally
    minSdk = flutter.minSdkVersion
    ...
}
```

Also update `android/app/src/main/kotlin/.../MainActivity.kt` package path if you rename the folder structure (or use Android Studio refactor).

### 3.3 Create upload keystore (one-time)

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload `
  -storetype JKS
```

Save passwords in a password manager. **Never commit the `.jks` file to Git.**

### 3.4 Configure signing

Create `android/key.properties` (add to `.gitignore`):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:/Users/YOUR_USER/upload-keystore.jks
```

Update `android/app/build.gradle.kts` — add before `android {`:

```kotlin
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}
```

Inside `android {`:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### 3.5 Build release App Bundle (AAB)

```powershell
flutter clean
flutter pub get
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Output file:

`build/app/outputs/bundle/release/app-release.aab`

### 3.6 Google Play Console steps

1. Go to [Google Play Console](https://play.google.com/console) → pay **$25** → create developer account.
2. **Create app** → name “Temple Book” → default language → app/game → free/paid.
3. Complete **required** sections (Dashboard will show blockers):
   - **App content:** Privacy policy, ads declaration, content rating questionnaire, target audience, data safety form (declare email, name, payments if collected).
   - **Store listing:** Short/full description, icon, screenshots, feature graphic.
   - **Privacy policy:** Host a simple page (GitHub Pages, Notion public page, or your S3/CloudFront URL) stating what data you collect (email, profile, payments).

### 3.7 Upload to Production (internal testing first)

1. **Testing** → **Internal testing** → Create release.
2. Upload `app-release.aab`.
3. Add tester Gmail addresses → share opt-in link → install and test login, temple select, payments.
4. Fix issues → upload new AAB with higher `versionCode` in `pubspec.yaml`:

```yaml
version: 1.0.1+2   # 1.0.1 = versionName, 2 = versionCode
```

5. When ready: **Production** → Create release → submit for review (review often takes 1–7 days).

### 3.8 Data safety (Supabase)

In Play Console **Data safety**, declare roughly:

- **Email address** — account management  
- **Name** — account / temple records  
- **Financial info** — if you store payment records in `payments`  
- Data encrypted in transit (HTTPS to Supabase)  
- Users can request account deletion (provide admin process or support email)

### 3.9 Post-launch

- Monitor **Supabase** → Logs, Auth users, Database size.
- Use **Play Console** → Vitals for crashes (enable Firebase Crashlytics later if needed).
- Plan backup: Supabase **Database** → Backups (free tier has limited retention; export SQL periodically).

---

## Quick reference commands

```powershell
# Dev run
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Android release for Play Store
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Web for AWS S3 / Netlify
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

---

## Recommended path for you (minimal cost)

1. **Today:** Supabase free project + run all 3 SQL migrations.  
2. **This week:** Internal testing on Play Console with 5–10 temple testers.  
3. **Optional:** Flutter web on S3/CloudFront or Netlify for committee admins on desktop.  
4. **Skip:** Self-hosting Supabase on AWS EC2 unless you have a strong reason (much harder to maintain).

---

## Security reminders

- Rotate Supabase keys if `supabase_config.dart` was ever committed publicly.
- Use **RLS** policies (migrations include temple-scoped rules).
- Never ship **service_role** key in the mobile app — only **anon** key.
- Enable email confirmation before public Play Store launch if you want verified accounts.

---

## Need help?

| Issue | Where to look |
|-------|----------------|
| SQL / RLS errors | Supabase → Logs → Postgres / API |
| Auth / reset email | Supabase → Authentication → Logs |
| Build failures | `flutter doctor -v` |
| Play rejection | Play Console → Policy status |

For self-hosted backend on a VM (Oracle/AWS EC2), see also `DEPLOYMENT_GUIDE.md` in this repo (advanced).
