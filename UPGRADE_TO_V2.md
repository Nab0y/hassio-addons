# Upgrade Guide: v1.x → v2.0.0 Multi-Tenant

## What's New in v2.0.0

### 🎉 Major Feature: Multi-Tenant Support

Version 2.0.0 introduces **multi-tenant mode**, allowing multiple Home Assistant users to each have their own Joplin account through a single addon instance.

### Key Changes

1. **Smart Proxy Architecture**
   - Port 41185 now runs an intelligent proxy
   - Automatically routes requests based on user token
   - Each user gets isolated Joplin profile

2. **Multiple Joplin CLI Instances**
   - One Joplin CLI per user
   - Sequential ports: 41184, 41185, 41186, etc.
   - Isolated data in `/data/joplin/profiles/<username>`

3. **Enhanced Configuration**
   - New `users` array in config
   - Per-user sync settings
   - Backward compatible with v1.x

## Should You Upgrade?

### Upgrade if:
- ✅ You have multiple Home Assistant users
- ✅ Each user needs their own Joplin account
- ✅ You want isolated note storage per user
- ✅ You need per-user voice notes/automations

### Stay on v1.x if:
- ⏸️ You only have one user
- ⏸️ You're happy with current setup
- ⏸️ You don't need multi-user features

## Upgrade Steps

### Option 1: Keep Single-User Mode (Backward Compatible)

**No configuration changes needed!**

Your existing configuration will continue to work:

```yaml
sync_target: 9
sync_server_url: "https://joplin.example.com"
sync_username: "user@example.com"
sync_password: "password"
# Don't add users array - stays in legacy mode
```

### Option 2: Migrate to Multi-Tenant Mode

**Before upgrading:**
1. Backup your data (Settings → Add-ons → HA Joplin Bridge → stop → backup `/data/joplin`)
2. Note your current configuration
3. Create Joplin Server accounts for each user (if using sync)

**New configuration:**

```yaml
users:
  - name: "user1"
    sync_target: 9
    sync_server_url: "https://joplin.example.com"
    sync_username: "user1@example.com"
    sync_password: "password1"
    locale: "en_US"
    
  - name: "user2"
    sync_target: 9
    sync_server_url: "https://joplin.example.com"
    sync_username: "user2@example.com"
    sync_password: "password2"
    locale: "en_US"
```

**Update Home Assistant:**

1. Update sensors:
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

2. Update REST commands:
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

## Testing After Upgrade

### 1. Check Mode
```bash
curl http://localhost:41186/health
```

Expected response:
- Single-user: `"mode": "single"`
- Multi-tenant: `"mode": "multi"`

### 2. Get Tokens
```bash
curl http://localhost:41186/token
```

### 3. Create Test Note
```bash
TOKEN=$(curl -s http://localhost:41186/token | jq -r '.users.user1.token')
curl -X POST "http://localhost:41185/notes?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Note", "body": "Testing v2.0"}'
```

## Troubleshooting

### Issue: Addon won't start after upgrade

**Solution:** Check configuration syntax in addon settings

### Issue: Old automations stopped working

**Cause:** Token endpoint changed format in multi-tenant mode

**Solution:** Update sensors to extract tokens from new format (see above)

### Issue: Notes missing

**Cause:** Data in old location, not migrated

**Solution:** Your data is safe in `/data/joplin`. Contact support for migration help.

## Rollback to v1.x

If you need to rollback:

1. Stop addon
2. Reinstall v1.2.0 from store
3. Restore old configuration
4. Start addon

Your data in `/data/joplin` is preserved.

## Documentation

- **Full Multi-Tenant Guide:** [MULTI_TENANT.md](ha-joplin-bridge/MULTI_TENANT.md)
- **Testing Guide:** [TESTING.md](ha-joplin-bridge/TESTING.md)
- **Main README:** [README.md](ha-joplin-bridge/README.md)
- **Changelog:** [CHANGELOG.md](ha-joplin-bridge/CHANGELOG.md)

## Support

- 🐛 [Report Issues](https://github.com/Nab0y/hassio-addons/issues)
- 💬 [Community Forum](https://community.home-assistant.io/)
- 📖 [Joplin Documentation](https://joplinapp.org/help/)

---

**Made with ❤️ for the Home Assistant community**
