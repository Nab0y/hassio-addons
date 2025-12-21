# Home Assistant Add-on: HA Joplin Bridge

![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg)
![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)
![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)
![AI Assisted](https://img.shields.io/badge/AI%20assisted-🤖-purple.svg)

Bridge between Home Assistant and Joplin with Web Clipper API support.

Bridge between Home Assistant and Joplin with full API support for creating automated notes, logging events, and synchronizing across devices.

## Features

- 🌐 **Web Clipper API** (Port 41185) - Full Joplin REST API for notes, notebooks, and tags
- 🔧 **Management API** (Port 41186) - Sync control, health monitoring, system information
- 👥 **Multi-Tenant Support** ⭐NEW⭐ - Multiple users, each with their own Joplin account
- 🔄 **Multi-Service Sync** - Joplin Server, Nextcloud, S3, and local filesystem
- 📝 **HA Automation Ready** - REST commands and sensors for seamless integration
- 🔒 **Encryption Support** - Optional end-to-end encryption for sensitive data
- 🚀 **Multi-Platform** - aarch64 and amd64 architecture support

## ⚠️ Sync Service Compatibility

This containerized add-on supports sync services that work well in Home Assistant environment:
- ✅ **Joplin Server** - Dedicated Joplin synchronization server
- ✅ **Nextcloud/WebDAV** - Popular self-hosted solution  
- ✅ **S3 Compatible** - Cloud storage (AWS S3, MinIO, etc.)
- ✅ **No Sync** - Local storage only

**Not supported:**
- ❌ **OAuth Services** - OneDrive, Dropbox, Joplin Cloud (require browser)
- ❌ **FileSystem Sync** - Not practical in containerized HA environment

## Installation

### Method 1: Add Repository (Recommended)

1. Navigate to **Settings** → **Add-ons** → **Add-on Store**
2. Click the **⋮** (three dots) in the top right corner
3. Select **Repositories**
4. Add this repository URL:
   ```
   https://github.com/Nab0y/hassio-addons
   ```
5. Click **Add** and wait for the repository to load
6. Find **"HA Joplin Bridge"** in the store and click **Install**

### Method 2: Manual Installation

For advanced users, copy the `ha-joplin-bridge` folder to your Home Assistant add-ons directory.

## Configuration

### 👥 Multi-Tenant Mode (NEW in v2.0)

**Support multiple users, each with their own Joplin account!**

```yaml
users:
  - name: "papa"
    sync_target: 9
    sync_server_url: "https://joplin.yourdomain.com"
    sync_username: "papa@family.com"
    sync_password: "password1"
    locale: "ru_RU"
    
  - name: "mama"
    sync_target: 9
    sync_server_url: "https://joplin.yourdomain.com"
    sync_username: "mama@family.com"
    sync_password: "password2"
    locale: "ru_RU"
    
  - name: "son"
    sync_target: 9
    sync_server_url: "https://joplin.yourdomain.com"
    sync_username: "son@family.com"
    sync_password: "password3"
```

📖 **[Full Multi-Tenant Documentation](MULTI_TENANT.md)** - Complete guide with examples

### User Configuration Parameters

Each user in the `users` array supports:

| Parameter | Description | Required |
|-----------|-------------|----------|
| `name` | User profile name (unique identifier) | ✅ Yes |
| `sync_target` | Sync service (0=None, 5=Nextcloud, 8=S3, 9=Joplin Server) | ✅ Yes |
| `sync_server_url` | Server URL for sync service | Only if sync_target > 0 |
| `sync_username` | Username for sync service | Only if sync_target > 0 |
| `sync_password` | Password for sync service | Only if sync_target > 0 |
| `enable_encryption` | Enable end-to-end encryption | No |
| `encryption_password` | Encryption password | Only if encryption enabled |
| `locale` | Interface language (e.g., `en_GB`, `ru_RU`) | No |
| `timezone` | Timezone (e.g., `UTC`, `Europe/Moscow`) | No |

## APIs

### Joplin Data API (Port 41185)
Complete Joplin REST API for managing notes, notebooks, and tags.

### Management API (Port 41186)  
Control sync, monitor status, and get system information.

## Quick Start

### 1. Get API Tokens for All Users
```bash
curl http://192.168.1.42:41186/token
```

Response:
```json
{
  "success": true,
  "mode": "multi",
  "tokens": {
    "papa": "abc123...",
    "mama": "def456...",
    "son": "ghi789..."
  }
}
```

### 2. Create First Note for Specific User
```bash
# Set token for papa
TOKEN="abc123..."

# Create notebook
curl -X POST "http://192.168.1.42:41185/folders?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Home Assistant Logs"}'

# Create note
curl -X POST "http://192.168.1.42:41185/notes?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Note", "body": "Hello from HA!", "parent_id": "FOLDER_ID"}'
```

**Note:** Each user uses the **same port 41185** but with their **own unique token**.

## Home Assistant Integration

### Sensors (configuration.yaml)

```yaml
sensor:
  # Get all user tokens
  - platform: rest
    name: joplin_tokens
    resource: http://192.168.1.42:41186/token
    value_template: "{{ value_json.mode }}"
    json_attributes:
      - tokens
    scan_interval: 3600
    
  # Sync status for Papa
  - platform: rest
    name: joplin_sync_papa
    resource: http://192.168.1.42:41186/sync/status?profile=papa
    value_template: >
      {% if value_json.status.running %}Syncing
      {% elif value_json.status.last_sync %}{{ as_timestamp(value_json.status.last_sync) | timestamp_custom('%d.%m %H:%M') }}
      {% else %}Never{% endif %}
    json_attributes: [status]
    
  # Sync status for Mama
  - platform: rest
    name: joplin_sync_mama
    resource: http://192.168.1.42:41186/sync/status?profile=mama
    value_template: >
      {% if value_json.status.running %}Syncing
      {% elif value_json.status.last_sync %}{{ as_timestamp(value_json.status.last_sync) | timestamp_custom('%d.%m %H:%M') }}
      {% else %}Never{% endif %}
    json_attributes: [status]
```

### REST Commands

```yaml
rest_command:
  # Create note for Papa
  joplin_create_note_papa:
    url: "http://192.168.1.42:41185/notes"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "token": "{{ state_attr('sensor.joplin_tokens', 'tokens')['papa'] }}"
      }
      
  # Create note for Mama
  joplin_create_note_mama:
    url: "http://192.168.1.42:41185/notes"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "token": "{{ state_attr('sensor.joplin_tokens', 'tokens')['mama'] }}"
      }
      
  # Sync for Papa
  joplin_sync_papa:
    url: "http://192.168.1.42:41186/sync"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: '{"profile": "papa", "background": true}'
    
  # Sync for Mama
  joplin_sync_mama:
    url: "http://192.168.1.42:41186/sync"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: '{"profile": "mama", "background": true}'
```

### Example Automations

#### Voice Note - Per User
```yaml
automation:
  # Papa's voice notes
  - alias: "Create Voice Note - Papa"
    trigger:
      - platform: event
        event_type: voice_note_received
        event_data:
          user: papa
    action:
      - service: rest_command.joplin_create_note_papa
        data:
          title: "🎤 Voice Note - {{ now().strftime('%H:%M') }}"
          body: "{{ trigger.event.data.text }}"
          
  # Mama's voice notes
  - alias: "Create Voice Note - Mama"
    trigger:
      - platform: event
        event_type: voice_note_received
        event_data:
          user: mama
    action:
      - service: rest_command.joplin_create_note_mama
        data:
          title: "🎤 Voice Note - {{ now().strftime('%H:%M') }}"
          body: "{{ trigger.event.data.text }}"
```

#### Auto-Sync Schedule
```yaml
automation:
  # Papa sync every 5 minutes
  - alias: "Joplin Sync - Papa"
    trigger:
      - platform: time_pattern
        minutes: "/5"
    action:
      - service: rest_command.joplin_sync_papa
      
  # Mama sync every 10 minutes
  - alias: "Joplin Sync - Mama"
    trigger:
      - platform: time_pattern
        minutes: "/10"
    action:
      - service: rest_command.joplin_sync_mama
```

#### Security Event - To Specific User
```yaml
automation:
  - alias: "Security Alert - To Papa"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: 'on'
    action:
      - service: rest_command.joplin_create_note_papa
        data:
          title: "🚨 Door Alert - {{ now().strftime('%H:%M') }}"
          body: |
            **Event:** Front door opened
            **Time:** {{ now().strftime('%d.%m.%Y at %H:%M:%S') }}
            **Alarm:** {{ states('alarm_control_panel.home') }}
```

## API Reference

### Management API (Port 41186)
- `GET /health` - Check add-on health and user count
- `GET /token` - Get API tokens for all users (multi-tenant mode)
- `POST /sync` - Start sync for specific user
  - Body: `{"profile": "username", "background": true}`
- `GET /sync/status?profile=username` - Get sync status for specific user

### Joplin Data API (Port 41185)
- All users access via **same port** with different tokens
- `GET /ping?token=TOKEN` - Health check
- `GET/POST /folders?token=TOKEN` - Notebooks
- `GET/POST /notes?token=TOKEN` - Notes
- `GET/POST /tags?token=TOKEN` - Tags
- Authentication: `?token=TOKEN` parameter required in all requests

## Troubleshooting

### Common Issues

**Add-on Won't Start**
- Check logs: Settings → Add-ons → HA Joplin Bridge → Logs
- Verify configuration syntax
- Ensure no port conflicts

**API Not Responding**  
- Wait 2 minutes for full startup
- Test: `curl http://localhost:41186/health`
- Check add-on status is "Started"

**Sync Failures**
- Verify server URL and credentials
- Check network connectivity
- Monitor: `curl http://localhost:41186/sync/status`

**Note Creation Fails**
- Create notebook first, then use `parent_id`
- Verify API token is valid
- Check JSON payload format

## Links

- 📖 [Multi-Tenant Documentation](MULTI_TENANT.md) - Complete guide with examples and API reference
- 📋 [Changelog](CHANGELOG.md) - Version history
- 🧪 [Testing Guide](TESTING.md) - How to test the addon
- 🐛 [Issues](https://github.com/Nab0y/hassio-addons/issues) - Bug reports and feature requests
- 📚 [Joplin API Docs](https://joplinapp.org/api/references/rest_api/) - Official API reference

---

**Made with ❤️ and 🤖 AI assistance for the Home Assistant community**