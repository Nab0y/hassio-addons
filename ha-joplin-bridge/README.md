# Home Assistant Add-on: HA Joplin Bridge

![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg)
![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)
![Version](https://img.shields.io/badge/version-1.0.8-blue.svg)
![AI Assisted](https://img.shields.io/badge/AI%20assisted-🤖-purple.svg)

Bridge between Home Assistant and Joplin with Web Clipper API support.

## ⚠️ Important Notice

**ATTENTION!** This add-on was created through AI-assisted development (vibe coding with LLM). While fully functional and tested, please be patient if you encounter any quirks. Bug reports and contributions are welcome!

## About

This add-on runs Joplin CLI inside Home Assistant, providing seamless integration between your smart home automations and note-taking workflow.

**Key Features:**
- 🌐 **Web Clipper API** - Create and manage notes programmatically
- 🔄 **Multi-platform Sync** - Joplin Server, Nextcloud, OneDrive, and more
- 🔧 **Management API** - Control sync, monitor status, get system info
- 📝 **Home Assistant Integration** - Perfect for automations and logging
- 🔒 **End-to-end Encryption** - Optional security for sensitive notes
- 🚀 **Modern Architecture** - Supports aarch64 and amd64 platforms

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

### Basic Settings

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `sync_target` | Synchronization service | `0` | 0=None, 2=File, 3=OneDrive, 5=Nextcloud, 7=Dropbox, 8=S3, 9=Joplin Server, 10=Joplin Cloud |
| `sync_interval` | Sync interval in seconds | `300` | 60-3600 |
| `locale` | Interface language | `en_GB` | Any valid locale |
| `timezone` | Timezone for timestamps | `UTC` | Any valid timezone |
| `enable_encryption` | Enable E2E encryption | `false` | true/false |
| `encryption_password` | Encryption password | `""` | Any password (hidden in UI) |
| `sync_server_url` | Sync server URL | `""` | Valid URL |
| `sync_username` | Sync username | `""` | Username for sync service |
| `sync_password` | Sync password | `""` | Password (hidden in UI) |

### Sync Configuration Examples

#### Joplin Server (`sync_target: 9`)
```yaml
sync_target: 9
sync_server_url: "https://your-joplin-server.com"
sync_username: "your-email@example.com"
sync_password: "your-password"
```

#### Nextcloud/WebDAV (`sync_target: 5`)
```yaml
sync_target: 5
sync_server_url: "https://cloud.example.com/remote.php/dav/files/username/Joplin"
sync_username: "your-username"
sync_password: "your-app-password"
```

#### No Sync (`sync_target: 0`)
```yaml
sync_target: 0
# No additional configuration needed
```

### Security Settings

For sensitive notes, enable end-to-end encryption:
```yaml
enable_encryption: true
encryption_password: "your-strong-password"
```

## Usage

After installation and configuration, the add-on provides two APIs:

### 🌐 Joplin Web Clipper API (Port 41185)
Standard Joplin Data API for creating and managing notes, notebooks, and tags.

**Base URL:** `http://YOUR_HA_IP:41185`

### 🔧 Management API (Port 41186)
Additional API for controlling the add-on and monitoring sync status.

**Base URL:** `http://YOUR_HA_IP:41186`

## Quick Start

### 1. Get API Token
```bash
curl http://YOUR_HA_IP:41186/token
```

### 2. Create Your First Note
```bash
# Get the token
TOKEN="your-api-token-here"

# Create a notebook first
FOLDER_ID=$(curl -X POST "http://YOUR_HA_IP:41185/folders?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Home Assistant"}' | jq -r '.id')

# Create a note in the notebook
curl -X POST "http://YOUR_HA_IP:41185/notes?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"My First Note\",
    \"body\": \"Created from Home Assistant!\",
    \"parent_id\": \"$FOLDER_ID\"
  }"
```

## Home Assistant Integration

### Sensors for Monitoring

Add to your `configuration.yaml`:

```yaml
sensor:
  # Get Joplin API token
  - platform: rest
    name: joplin_token
    resource: http://localhost:41186/token
    value_template: "{{ value_json.token }}"
    scan_interval: 3600
    
  # Monitor sync status
  - platform: rest
    name: joplin_sync_status
    resource: http://localhost:41186/sync/status
    value_template: >
      {% if value_json.status.running %}
        Syncing...
      {% elif value_json.status.last_sync %}
        {{ as_timestamp(value_json.status.last_sync) | timestamp_custom('%d.%m %H:%M') }}
      {% else %}
        Never synced
      {% endif %}
    json_attributes:
      - status
```

### REST Commands

```yaml
rest_command:
  # Create a note
  joplin_create_note:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "parent_id": "{{ folder_id | default('') }}"
      }
      
  # Trigger sync
  joplin_sync:
    url: "http://localhost:41186/sync"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: '{"background": true}'
```

### Automation Examples

#### 📝 Log Important Events
```yaml
automation:
  - alias: "Important Events to Joplin"
    trigger:
      - platform: state
        entity_id: binary_sensor.front_door
        to: 'on'
      - platform: state
        entity_id: alarm_control_panel.home
        to: 'triggered'
    action:
      - service: rest_command.joplin_create_note
        data:
          title: "🏠 {{ trigger.to_state.attributes.friendly_name }}"
          body: |
            **Event:** {{ trigger.to_state.state }}
            **Time:** {{ now().strftime('%d.%m.%Y at %H:%M:%S') }}
            **Previous State:** {{ trigger.from_state.state }}
            
            {% if trigger.entity_id == 'alarm_control_panel.home' %}
            🚨 **SECURITY ALERT!** Check the house immediately.
            {% else %}
            ℹ️ Regular home activity logged.
            {% endif %}
```

#### 📊 Weekly Home Report
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
            # Smart Home Weekly Summary
            
            ## 🌡️ Climate
            - Average Temperature: {{ states('sensor.average_temperature') }}°C
            - Average Humidity: {{ states('sensor.average_humidity') }}%
            
            ## ⚡ Energy
            - Total Consumption: {{ states('sensor.energy_total') }} kWh
            - Estimated Cost: ${{ (states('sensor.energy_total') | float * 0.12) | round(2) }}
            
            ## 🚪 Security
            - Door openings: {{ states('counter.door_openings') }}
            - Motion detections: {{ states('counter.motion_detections') }}
            
            *Generated automatically on {{ now().strftime('%d.%m.%Y at %H:%M') }}*
```

#### 🔄 Daily Sync
```yaml
automation:
  - alias: "Daily Joplin Sync"
    trigger:
      platform: time
      at: "06:00:00"
    action:
      - service: rest_command.joplin_sync
```

## API Reference

### Management API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Check add-on health |
| `/token` | GET | Get Joplin API token |
| `/info` | GET | Get system information |
| `/sync` | POST | Start synchronization |
| `/sync/status` | GET | Get sync status |

### Joplin Data API

Full Joplin REST API available at port 41185. Key endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ping` | GET | API health check |
| `/folders` | GET/POST | Manage notebooks |
| `/notes` | GET/POST | Manage notes |
| `/notes/{id}` | GET/PUT/DELETE | Specific note operations |
| `/tags` | GET/POST | Manage tags |

## Troubleshooting

### Add-on Won't Start
1. Check logs in **Settings** → **Add-ons** → **HA Joplin Bridge** → **Logs**
2. Verify configuration syntax
3. Ensure no port conflicts with other add-ons

### Sync Issues
1. Check sync configuration (server URL, credentials)
2. Verify network connectivity to sync target
3. Monitor sync status via `/sync/status` endpoint

### API Not Responding
1. Wait 1-2 minutes for full startup
2. Check that add-on status is "Started"
3. Try accessing from Home Assistant terminal:
   ```bash
   curl http://localhost:41186/health
   ```

### Common Configuration Errors
- Invalid `sync_target` number
- Incorrect server URLs (missing https://)
- Wrong WebDAV paths for Nextcloud
- Network firewall blocking sync ports

## Advanced Usage

### Using with Node-RED
If you have Node-RED installed, you can create flows that interact with Joplin:

1. Use HTTP request nodes to call the APIs
2. Parse responses with JSON nodes
3. Create complex automation workflows

### Custom Scripts
Create shell scripts that interact with Joplin:

```bash
#!/bin/bash
TOKEN=$(curl -s http://localhost:41186/token | jq -r '.token')
curl -X POST "http://localhost:41185/notes?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Daily Backup Log","body":"Backup completed successfully"}'
```

## Security Considerations

- **Network Access:** APIs are only accessible within your Home Assistant network
- **Encryption:** Enable end-to-end encryption for sensitive notes
- **Tokens:** API tokens persist between restarts and are stored in Joplin configuration
- **Sync Security:** Use app passwords for Nextcloud/WebDAV sync

## Contributing & Support

### 🐛 Bug Reports
Found an issue? Please report it on [GitHub Issues](https://github.com/Nab0y/hassio-addons/issues).

### 💡 Feature Requests
Have an idea? We'd love to hear it! Create an issue with the "enhancement" label.

### 🤝 Contributing
This is an AI-assisted project, so contributions from the community are especially welcome:
- Code improvements and optimizations
- Documentation enhancements
- Bug fixes and testing
- New automation examples

### 📚 Resources
- [Joplin API Documentation](https://joplinapp.org/api/references/rest_api/)
- [Home Assistant Automation](https://www.home-assistant.io/docs/automation/)
- [Add-on Repository](https://github.com/Nab0y/hassio-addons)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

## License

MIT License - see [LICENSE](../LICENSE) for details.

---

**Made with ❤️ and 🤖 AI assistance for the Home Assistant community**

*Remember: If it works, it's not stupid!* 😊