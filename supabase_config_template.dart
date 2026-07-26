class SupabaseConfig {
  // ⚠️  CHANGE THIS: Replace <PUBLIC_IP> with your Oracle VM public IP
  // Example: 'http://140.xxx.xxx.xxx:3000'
  static const url = 'http://<PUBLIC_IP>:3000';
  
  // This is a default test JWT anon key for development
  // For production, generate a new one: base64('{"iss":"supabase","ref":"example","role":"anon","iat":1623859200,"exp":2524647200}')
  static const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4YW1wbGUiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTYyMzg1OTIwMCwiZXhwIjoyNTI0NjQ3MjAwfQ.rjsV3GZ0tZWdtWl0w6-dBvnmRG_80sSqkqykxnJI_JI';
}
