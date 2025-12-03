# Home Assistant Add-on: HA Joplin Bridge

![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg)
![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)
![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)
![AI Assisted](https://img.shields.io/badge/AI%20assisted-🤖-purple.svg)

Bridge between Home Assistant and Joplin with Web Clipper API support.

Bridge between Home Assistant and Joplin with full API support for creating automated notes, logging events, and synchronizing across devices.

## Features

- 🌐 **Web Clipper API** (Port 41185) - Full Joplin REST API for notes, notebooks, and tags
- 🔧 **Management API** (Port 41186) - Sync control, health monitoring, system information
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

### Quick Setup Examples

#### Joplin Server
```yaml
sync_target: 9
sync_server_url: "https://your-joplin-server.com"
sync_username: "your-email@example.com"
sync_password: "your-password"
enable_encryption: true
encryption_password: "your-encryption-password"
```

#### Nextcloud/WebDAV
```yaml
sync_target: 5
sync_server_url: "https://cloud.example.com/remote.php/dav/files/username/Joplin"
sync_username: "your-username"
sync_password: "your-app-password"
```

#### S3 Compatible Storage
```yaml
sync_target: 8
sync_server_url: "https://s3.amazonaws.com"
sync_username: "your-access-key-id"
sync_password: "your-secret-access-key"
```

#### Local Only (No Sync)
```yaml
sync_target: 0
locale: "en_GB"
timezone: "UTC"
```

### Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sync_target` | Sync service (0=None, 5=Nextcloud, 8=S3, 9=Joplin Server) | `0` |
| `sync_server_url` | Server URL for sync service | `""` |
| `sync_username` | Username for sync service | `""` |
| `sync_password` | Password for sync service | `""` |
| `enable_encryption` | Enable end-to-end encryption | `false` |
| `encryption_password` | Encryption password | `""` |
| `sync_interval` | Auto-sync interval in seconds | `300` |
| `locale` | Interface language | `en_GB` |
| `timezone` | Timezone for timestamps | `UTC` |

## APIs

### Joplin Data API (Port 41185)
Complete Joplin REST API for managing notes, notebooks, and tags.

### Management API (Port 41186)  
Control sync, monitor status, and get system information.

## Quick Start

### Get API Token
```bash
curl http://localhost:41186/token
```

### Create First Note
```bash
# Create notebook
curl -X POST "http://localhost:41185/folders?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Home Assistant Logs"}'

# Create note
curl -X POST "http://localhost:41185/notes?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Note", "body": "Hello from HA!", "parent_id": "FOLDER_ID"}'
```

## Home Assistant Integration

### Sensors (configuration.yaml)

```yaml
sensor:
  # API Token
  - platform: rest
    name: joplin_token
    resource: http://localhost:41186/token
    value_template: "{{ value_json.token }}"
    scan_interval: 3600
    
  # Sync Status
  - platform: rest
    name: joplin_sync_status  
    resource: http://localhost:41186/sync/status
    value_template: >
      {% if value_json.status.running %}Syncing
      {% elif value_json.status.last_sync %}{{ as_timestamp(value_json.status.last_sync) | timestamp_custom('%d.%m %H:%M') }}
      {% else %}Never synced{% endif %}
    json_attributes: [status]
```

### REST Commands

```yaml
rest_command:
  # Create note
  joplin_create_note:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: '{"title": "{{ title }}", "body": "{{ body }}", "parent_id": "{{ folder_id | default(\"\") }}"}'
      
  # Trigger sync
  joplin_sync:
    url: "http://localhost:41186/sync"
    method: POST
    payload: '{"background": true}'
```

### Example Automations

#### Security Event Logger
```yaml
automation:
  - alias: "Log Security Events"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: 'on'
    action:
      - service: rest_command.joplin_create_note
        data:
          title: "🚨 {{ trigger.to_state.attributes.friendly_name }} - {{ now().strftime('%H:%M') }}"
          body: |
            **Event:** Door opened
            **Time:** {{ now().strftime('%d.%m.%Y at %H:%M:%S') }}
            **Status:** {{ states('alarm_control_panel.home') }}
```

#### Weekly Report
```yaml
automation:
  - alias: "Weekly Home Report"
    trigger:
      platform: time
      at: "09:00:00"  
    condition:
      condition: time
      weekday: [sun]
    action:
      - service: rest_command.joplin_create_note
        data:
          title: "📊 Weekly Report {{ now().strftime('%d.%m.%Y') }}"
          body: |
            # Smart Home Summary
            
            **Energy:** {{ states('sensor.energy_total') }} kWh
            **Temperature:** {{ states('sensor.average_temperature') }}°C
            **Security Events:** {{ states('counter.door_openings') }}
            
            *Generated {{ now().strftime('%d.%m.%Y at %H:%M') }}*
```

## API Reference

### Management API (Port 41186)
- `GET /health` - Check add-on health
- `GET /token` - Get API token  
- `GET /info` - System information
- `POST /sync` - Start sync
- `GET /sync/status` - Sync status

### Joplin Data API (Port 41185)
- `GET /ping` - Health check
- `GET/POST /folders` - Notebooks
- `GET/POST /notes` - Notes
- `GET/POST /tags` - Tags
- Authentication: `?token=TOKEN` required

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

- 📖 [Full Documentation](DOCS.md) - Complete API reference and examples
- 📋 [Changelog](CHANGELOG.md) - Version history
- 🐛 [Issues](https://github.com/Nab0y/hassio-addons/issues) - Bug reports and feature requests
- 📚 [Joplin API Docs](https://joplinapp.org/api/references/rest_api/) - Official API reference

---

**Made with ❤️ and 🤖 AI assistance for the Home Assistant community**