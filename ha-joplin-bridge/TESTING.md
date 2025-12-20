# Testing Guide for v2.0.0 Multi-Tenant

## Quick Test Plan

### 1. Single-User Mode Test (Legacy)

**Configuration:**
```yaml
sync_target: 0
users: []
```

**Verification:**
```bash
# Health check
curl http://localhost:41186/health
# Expected: "mode": "single", "users_count": 1

# Token
curl http://localhost:41186/token
# Expected: single token for "default"

# Create note
TOKEN=$(curl -s http://localhost:41186/token | jq -r '.token')
curl -X POST "http://localhost:41185/notes?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Note", "body": "Single-user test"}'
```

### 2. Multi-Tenant Mode Test

**Configuration:**
```yaml
users:
  - name: "user1"
    sync_target: 0
  - name: "user2"
    sync_target: 0
```

**Verification:**
```bash
# Health check
curl http://localhost:41186/health
# Expected: "mode": "multi", "users_count": 2

# Tokens
curl http://localhost:41186/token
# Expected: users object with user1 and user2

# Extract tokens
TOKEN_USER1=$(curl -s http://localhost:41186/token | jq -r '.users.user1.token')
TOKEN_USER2=$(curl -s http://localhost:41186/token | jq -r '.users.user2.token')

echo "User1 token: $TOKEN_USER1"
echo "User2 token: $TOKEN_USER2"

# Create note for user1
curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER1" \
  -H "Content-Type: application/json" \
  -d '{"title": "Note for User1", "body": "This is user1 note"}'

# Create note for user2
curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER2" \
  -H "Content-Type: application/json" \
  -d '{"title": "Note for User2", "body": "This is user2 note"}'

# Check user1 notes
curl "http://localhost:41185/notes?token=$TOKEN_USER1&fields=id,title"

# Check user2 notes
curl "http://localhost:41185/notes?token=$TOKEN_USER2&fields=id,title"
```

### 3. Data Isolation Test

```bash
# User1 should not see User2's notes
curl "http://localhost:41185/notes?token=$TOKEN_USER1&fields=id,title"
# Should return only user1 notes

# User2 should not see User1's notes
curl "http://localhost:41185/notes?token=$TOKEN_USER2&fields=id,title"
# Should return only user2 notes

# Invalid token should return error
curl "http://localhost:41185/notes?token=invalid_token"
# Expected: 403 Forbidden
```

### 4. Synchronization Test

```bash
# Sync user1
curl -X POST http://localhost:41186/sync \
  -H "Content-Type: application/json" \
  -d '{"profile": "user1", "background": true}'

# Check user1 sync status
curl "http://localhost:41186/sync/status?profile=user1"

# Check all users status
curl "http://localhost:41186/sync/status"
```

### 5. Log Verification

In Home Assistant → Settings → Add-ons → HA Joplin Bridge → Logs

Expected messages:
```
Multi-user mode detected: 2 users
Setting up user 1/2: user1
Configuring Joplin profile: user1 on port 41184
Starting Joplin server for user1 on localhost:41184
user1 Joplin PID: XXXX
Setting up user 2/2: user2
Configuring Joplin profile: user2 on port 41185
Starting Joplin server for user2 on localhost:41185
user2 Joplin PID: YYYY
Starting Management API server on port 41186
Starting Joplin Data API Proxy on port 41185
Multi-tenant proxy active on port 41185
```

## Testing with Joplin Server

### Configuration for Real Joplin Server

```yaml
users:
  - name: "test_user1"
    sync_target: 9
    sync_server_url: "https://your-joplin-server.com"
    sync_username: "user1@example.com"
    sync_password: "password1"
    locale: "en_US"
    
  - name: "test_user2"
    sync_target: 9
    sync_server_url: "https://your-joplin-server.com"
    sync_username: "user2@example.com"
    sync_password: "password2"
    locale: "en_US"
```

### Sync Verification

```bash
# Create note for user1
TOKEN_USER1=$(curl -s http://localhost:41186/token | jq -r '.users.test_user1.token')
curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER1" \
  -H "Content-Type: application/json" \
  -d '{"title": "Sync Test User1", "body": "Testing sync"}'

# Synchronize
curl -X POST http://localhost:41186/sync \
  -H "Content-Type: application/json" \
  -d '{"profile": "test_user1", "background": false}'

# Check in Joplin Desktop or Mobile with user1@example.com account
```

## Home Assistant Integration Test

### Sensor for Token Extraction

```yaml
sensor:
  - platform: rest
    name: joplin_tokens
    resource: http://localhost:41186/token
    value_template: "OK"
    json_attributes:
      - users
    scan_interval: 86400
  
  - platform: template
    sensors:
      joplin_token_user1:
        value_template: "{{ state_attr('sensor.joplin_tokens', 'users')['user1']['token'] }}"
```

### REST Command

```yaml
rest_command:
  joplin_create_note_user1:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token_user1') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}"
      }
```

### Automation Test

```yaml
automation:
  - alias: "Test Joplin Multi-Tenant"
    trigger:
      - platform: state
        entity_id: input_boolean.test_joplin
        to: 'on'
    action:
      - service: rest_command.joplin_create_note_user1
        data:
          title: "Test from HA"
          body: "This is a test note created from Home Assistant automation"
```

## Common Issues and Solutions

### Issue: "Port already in use"

**Cause:** Process from previous run still active

**Solution:**
```bash
# Find processes
ps aux | grep joplin

# Kill processes
kill -9 <PID>
```

### Issue: Token not returned

**Cause:** Joplin CLI hasn't initialized yet

**Solution:** Wait 30-60 seconds after addon startup

### Issue: 502 Bad Gateway when creating note

**Cause:** Joplin CLI instance for this user not running

**Solution:** Check logs and restart addon

## Performance Test

### Create 100 Notes for Each User

```bash
TOKEN_USER1=$(curl -s http://localhost:41186/token | jq -r '.users.user1.token')
TOKEN_USER2=$(curl -s http://localhost:41186/token | jq -r '.users.user2.token')

for i in {1..100}; do
  curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER1" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"User1 Note $i\", \"body\": \"Test note number $i\"}" &
    
  curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER2" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"User2 Note $i\", \"body\": \"Test note number $i\"}" &
done

wait
echo "Created 200 notes total"
```

## Release Checklist

- [ ] Single-user mode works
- [ ] Multi-tenant mode works with 2+ users
- [ ] Data isolation between users
- [ ] Unique tokens for each user
- [ ] API endpoints return correct data
- [ ] Sync works for each profile separately
- [ ] Logs show correct initialization
- [ ] Backward compatibility with v1.x
- [ ] Documentation is current
- [ ] Examples in documentation work

## Security Testing

### Test Invalid Token Access

```bash
# Try to access with wrong token
curl "http://localhost:41185/notes?token=wrongtoken123"
# Expected: 403 Forbidden with error message

# Try to access without token
curl "http://localhost:41185/notes"
# Expected: 401 Unauthorized
```

### Test Cross-User Access

```bash
# Get both tokens
TOKEN_USER1=$(curl -s http://localhost:41186/token | jq -r '.users.user1.token')
TOKEN_USER2=$(curl -s http://localhost:41186/token | jq -r '.users.user2.token')

# Create note for user1
NOTE_ID=$(curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER1" \
  -H "Content-Type: application/json" \
  -d '{"title": "User1 Private Note", "body": "Secret"}' | jq -r '.id')

# Try to access user1's note with user2's token
curl "http://localhost:41185/notes/$NOTE_ID?token=$TOKEN_USER2"
# Expected: Should not return the note or return error
```

## Resource Monitoring

### Check Memory Usage

```bash
# In addon container
ps aux | grep joplin
# Note the RSS column for memory usage per process

# Total for all Joplin instances
ps aux | grep joplin | awk '{sum+=$6} END {print sum/1024 " MB"}'
```

### Check Port Usage

```bash
# List all listening ports
netstat -tlnp | grep joplin
# or
ss -tlnp | grep joplin
```

## Advanced Testing

### Test Concurrent Requests

```bash
TOKEN_USER1=$(curl -s http://localhost:41186/token | jq -r '.users.user1.token')

# Send 10 concurrent requests
for i in {1..10}; do
  curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER1" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"Concurrent Test $i\", \"body\": \"Test\"}" &
done

wait
echo "All concurrent requests completed"
```

### Test Failover

```bash
# Kill one Joplin instance
ps aux | grep "joplin.*user1"
kill <PID>

# Try to create note for that user
TOKEN_USER1=$(curl -s http://localhost:41186/token | jq -r '.users.user1.token')
curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER1" \
  -H "Content-Type: application/json" \
  -d '{"title": "Failover Test", "body": "Should fail"}'
# Expected: 502 Bad Gateway

# Other users should still work
TOKEN_USER2=$(curl -s http://localhost:41186/token | jq -r '.users.user2.token')
curl -X POST "http://localhost:41185/notes?token=$TOKEN_USER2" \
  -H "Content-Type: application/json" \
  -d '{"title": "User2 Still Works", "body": "Success"}'
# Expected: Success
```
