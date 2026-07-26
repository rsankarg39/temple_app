# Temple Book App - Complete Deployment & Testing Guide

## Phase 1: Oracle Cloud VM Setup

### Step 1: Create Oracle Cloud Free Tier VM

1. Go to [oracle.com/cloud/free](https://www.oracle.com/cloud/free)
2. Sign up or log in
3. Navigate to **Compute > Instances**
4. Click **Create Instance**
5. Configure:
   - **Name**: `temple-book-backend`
   - **Image**: Ubuntu 22.04 (Always Free eligible)
   - **Shape**: VM.Standard.A1.Flex (Always Free, 4 OCPU, 24 GB RAM)
   - **Subnet**: Select available Always-Free subnet
   - **SSH Key**: Download and save the private key
6. Click **Create**
7. Wait for instance to be **Running** (5-10 minutes)
8. Note the **Public IP Address** (e.g., `140.x.x.x`)

### Step 2: Connect to VM via SSH

```powershell
# On Windows PowerShell, copy the SSH key to your .ssh folder
$keyPath = "$env:USERPROFILE\.ssh\oracle-vm-key.pem"
# Paste your downloaded key into this file

# Connect to VM
ssh -i $keyPath ubuntu@<PUBLIC_IP>
# Replace <PUBLIC_IP> with the IP from Step 1
```

### Step 3: Install Docker and Docker Compose

```bash
# Once connected to the VM:

# Update system
sudo apt update
sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version

# Log out and back in for docker group to take effect
exit
```

---

## Phase 2: Deploy Backend Stack

### Step 1: Create Docker Compose File

SSH back into the VM and create the deployment directory:

```bash
ssh -i $keyPath ubuntu@<PUBLIC_IP>

# Create directories
mkdir -p ~/temple-backend/postgres
cd ~/temple-backend
```

Create `docker-compose.yml`:

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: temple_postgres
    environment:
      POSTGRES_PASSWORD: temple_postgres_secure_password_2024
      POSTGRES_DB: temple_db
      POSTGRES_USER: postgres
    ports:
      - "5432:5432"
    volumes:
      - ./postgres:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - temple-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  supabase-auth:
    image: supabase/gotrue:latest
    container_name: temple_gotrue
    environment:
      GOTRUE_JWT_SECRET: "your-super-secret-jwt-key-change-this-32-chars!!!"
      GOTRUE_JWT_EXP: 3600
      GOTRUE_DB_DRIVER: postgres
      DATABASE_URL: "postgres://postgres:temple_postgres_secure_password_2024@postgres:5432/temple_db"
      GOTRUE_SITE_URL: "http://<PUBLIC_IP>:3000"
      GOTRUE_API_HOST: "0.0.0.0"
      GOTRUE_API_PORT: 9999
      GOTRUE_SMTP_ADMIN_EMAIL: "admin@templebook.app"
      GOTRUE_MAILER_AUTOCONFIRM: "true"
      GOTRUE_EXTERNAL_EMAIL_ENABLED: "true"
    ports:
      - "9999:9999"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - temple-network
    restart: unless-stopped

  postgrest:
    image: postgrest/postgrest:latest
    container_name: temple_postgrest
    environment:
      PGRST_DB_URI: "postgres://postgres:temple_postgres_secure_password_2024@postgres:5432/temple_db"
      PGRST_DB_SCHEMAS: "public"
      PGRST_JWT_SECRET: "your-super-secret-jwt-key-change-this-32-chars!!!"
      PGRST_DB_ANON_ROLE: "anon"
    ports:
      - "3000:3000"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - temple-network
    restart: unless-stopped

networks:
  temple-network:
    driver: bridge
EOF
```

### Step 2: Create Database Initialization Script

```bash
cat > init.sql << 'EOF'
-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create auth schema (required by GoTrue)
CREATE SCHEMA IF NOT EXISTS auth;

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  phone TEXT UNIQUE,
  gender TEXT,
  kulam TEXT,
  marital_status TEXT,
  business TEXT,
  photo_url TEXT,
  role TEXT DEFAULT 'user',
  is_family_head BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create family heads table
CREATE TABLE IF NOT EXISTS public.familyheads (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  nakshatram TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create committee members table
CREATE TABLE IF NOT EXISTS public.committeemembers (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  role TEXT,
  profile_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create payments table
CREATE TABLE IF NOT EXISTS public.payments (
  id SERIAL PRIMARY KEY,
  payer TEXT NOT NULL,
  amount DECIMAL(10, 2),
  purpose TEXT,
  payer_user_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create poojas table
CREATE TABLE IF NOT EXISTS public.poojas (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create events table
CREATE TABLE IF NOT EXISTS public.events (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create employees table
CREATE TABLE IF NOT EXISTS public.employees (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  designation TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create MPIN storage table
CREATE TABLE IF NOT EXISTS public.user_mpins (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  mpin_hash TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create RPC functions for MPIN operations
CREATE OR REPLACE FUNCTION public.set_user_mpin(p_mpin TEXT)
RETURNS void AS $$
BEGIN
  INSERT INTO public.user_mpins (user_id, mpin_hash)
  VALUES (auth.uid(), crypt(p_mpin, gen_salt('bf')))
  ON CONFLICT (user_id) DO UPDATE
  SET mpin_hash = crypt(p_mpin, gen_salt('bf')),
      updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.verify_user_mpin(p_mpin TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  stored_hash TEXT;
BEGIN
  SELECT mpin_hash INTO stored_hash
  FROM public.user_mpins
  WHERE user_id = auth.uid();
  
  IF stored_hash IS NULL THEN
    RETURN false;
  END IF;
  
  RETURN stored_hash = crypt(p_mpin, stored_hash);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.has_user_mpin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 FROM public.user_mpins WHERE user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_mpins ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can view own MPIN status"
  ON public.user_mpins FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own MPIN"
  ON public.user_mpins FOR ALL
  USING (auth.uid() = user_id);

-- Public read access to certain tables
CREATE POLICY "Anyone can read family heads"
  ON public.familyheads FOR SELECT
  USING (true);

CREATE POLICY "Anyone can read committee members"
  ON public.committeemembers FOR SELECT
  USING (true);

CREATE POLICY "Anyone can read payments"
  ON public.payments FOR SELECT
  USING (true);

CREATE POLICY "Anyone can read poojas"
  ON public.poojas FOR SELECT
  USING (true);

CREATE POLICY "Anyone can read events"
  ON public.events FOR SELECT
  USING (true);

CREATE POLICY "Anyone can read employees"
  ON public.employees FOR SELECT
  USING (true);

-- Insert sample data
INSERT INTO public.poojas (name, description) VALUES
  ('Daily Prayers', 'Morning prayers at 6:00 AM'),
  ('Sunday Services', 'Weekly service on Sunday at 10:00 AM'),
  ('Monthly Pooja', 'First Sunday of every month at 4:00 PM')
ON CONFLICT DO NOTHING;

INSERT INTO public.employees (name, designation) VALUES
  ('Ravi Kumar', 'Temple Priest'),
  ('Lakshmi', 'Maintenance Staff'),
  ('Hari', 'Security')
ON CONFLICT DO NOTHING;
EOF
```

### Step 3: Start the Services

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f

# Wait 30-60 seconds for services to start
sleep 60
```

### Step 4: Verify Backend is Running

```bash
# Test PostgreSQL
docker exec temple_postgres psql -U postgres -d temple_db -c "SELECT 1;"

# Test GoTrue (Auth)
curl -s http://localhost:9999/health | jq .

# Test PostgREST (API)
curl -s http://localhost:3000/profiles | jq .
```

---

## Phase 3: Configure Flutter App

### Step 1: Update supabase_config.dart

Replace [supabase_config.dart](supabase_config.dart) with:

```dart
class SupabaseConfig {
  static const url = 'http://<PUBLIC_IP>:3000';
  static const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4YW1wbGUiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTYyMzg1OTIwMCwiZXhwIjoyNTI0NjQ3MjAwfQ.rjsV3GZ0tZWdtWl0w6-dBvnmRG_80sSqkqykxnJI_JI';
}
```

Replace:
- `<PUBLIC_IP>` with your Oracle VM public IP (e.g., `140.x.x.x`)
- Keep the `anonKey` as is (it's a test JWT token for development)

---

## Phase 4: Testing Phone + MPIN Authentication

### Test 1: Build and Run Flutter App

```powershell
# In your Flutter project directory:

# Clean build
flutter clean
flutter pub get

# Build APK for Android testing
flutter build apk --release

# Or run on emulator
flutter run --release
```

### Test 2: Register with Phone Number

**Steps:**
1. Launch app on Android device/emulator
2. Click **Register** tab
3. Fill in:
   - Full Name: `Sankar Test`
   - Gender: `Male`
   - Kulam: `Bharadwaja`
   - Marital Status: `Single`
   - Phone Number: `9876543210` (any 10-digit starting with 6-9)
   - Password: `password123` (or leave blank)
   - MPIN: `1234`
   - Confirm MPIN: `1234`
4. Click **Register**
5. **Expected Result**: "Registration successful" message

### Test 3: Login with Password

**Steps:**
1. Click **Login** tab
2. Enter Phone: `9876543210`
3. Select **Password** radio button
4. Enter Password: `password123`
5. Click **Login**
6. **Expected Result**: MPIN verification page (since MPIN was set)

### Test 4: Verify MPIN

**Steps:**
1. On MPIN verification page, enter: `1234`
2. Click **Continue**
3. **Expected Result**: Logged in successfully, see home page

### Test 5: Login with MPIN

**Steps:**
1. Click logout (top right icon on home)
2. Click **Login** tab
3. Enter Phone: `9876543210`
4. Select **MPIN** radio button
5. Enter MPIN: `1234`
6. Click **Login**
7. Skip MPIN verification (already verified)
8. **Expected Result**: Logged in successfully

### Test 6: Test Without MPIN

**Steps:**
1. Register new account without MPIN:
   - Leave MPIN fields empty
   - Enter Password: `testpass123`
2. Log in with password
3. **Expected Result**: Set MPIN page appears
4. Set MPIN: `5678`
5. **Expected Result**: Home page loads

### Test 7: Invalid Credentials

**Steps:**
1. Enter Phone: `9876543210`
2. Enter wrong Password: `wrongpass`
3. Click **Login**
4. **Expected Result**: Error message "Invalid login credentials"

### Test 8: Invalid Phone Validation

**Steps:**
1. Enter Phone: `123456` (less than 10 digits)
2. Click **Login**
3. **Expected Result**: Error "Enter a valid 10-digit Indian phone number"

### Test 9: Invalid MPIN Validation

**Steps:**
1. Register with MPIN: `12` (only 2 digits)
2. Click **Register**
3. **Expected Result**: Error "MPIN must be exactly 4 digits"

---

## Phase 5: Database Verification

### Check Backend Data

```bash
# SSH to VM
ssh -i $keyPath ubuntu@<PUBLIC_IP>

# View registered users
docker exec temple_postgres psql -U postgres -d temple_db -c "SELECT id, email, phone FROM auth.users;"

# View profile data
docker exec temple_postgres psql -U postgres -d temple_db -c "SELECT * FROM public.profiles;"

# View MPIN records
docker exec temple_postgres psql -U postgres -d temple_db -c "SELECT * FROM public.user_mpins;"
```

---

## Phase 6: Production Checklist

- [ ] Change `GOTRUE_JWT_SECRET` to a strong 32-character random string
- [ ] Change PostgreSQL password (`temple_postgres_secure_password_2024`)
- [ ] Enable SSL/TLS for connections (use reverse proxy like Nginx)
- [ ] Set up firewall rules (port 3000 accessible only from app IPs)
- [ ] Configure email sending for auth notifications
- [ ] Set up automated database backups
- [ ] Monitor service health with cron jobs

---

## Troubleshooting

### Services not starting
```bash
docker-compose down
docker-compose up -d --build
docker-compose logs
```

### Port already in use
```bash
# Change port in docker-compose.yml and rebuild
docker-compose down
docker-compose up -d
```

### Database connection errors
```bash
# Check postgres health
docker exec temple_postgres pg_isready -U postgres

# View init logs
docker logs temple_postgres
```

### App can't connect to backend
- Verify Oracle VM Security List allows port 3000
- Check app URL in `supabase_config.dart` matches VM public IP
- Test connection: `curl -s http://<PUBLIC_IP>:3000/profiles`

