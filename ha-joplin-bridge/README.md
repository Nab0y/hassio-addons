# Home Assistant Add-on: Joplin CLI

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

Joplin CLI with Web Clipper API for Home Assistant automations.

## About

This add-on runs Joplin CLI in Home Assistant, providing:

- 🌐 **Web Clipper API** for creating and managing notes
- 🔄 **Synchronization** with various services (Joplin Server, Nextcloud, OneDrive, etc.)
- 🔧 **Management API** for sync control and monitoring
- 📝 **Home Assistant automations** with Joplin notes

## Installation

1. Navigate to **Supervisor** > **Add-on Store**
2. Click the three dots in the top right corner and select **Repositories**
3. Add the URL of this repository
4. Find "Joplin CLI" in the add-on list and click **Install**

## Configuration

### Basic Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sync_target` | Sync type (0=None, 9=Joplin Server, 5=Nextcloud) | `0` |
| `sync_interval` | Sync interval in seconds | `300` |
| `locale` | Interface language | `"en_GB"` |
| `timezone` | Timezone | `"UTC"` |

### Sync Configuration

For **Joplin Server** (`sync_target: 9`):

```yaml
sync_config:
  server_url: "https://your-joplin-server.com"
  username: "your-email@example.com"
  password: "your-password"
```

For **Nextcloud/WebDAV** (`sync_target: 5`):

```yaml
sync_config:
  server_url: "https://cloud.example.com/remote.php/dav/files/username/Joplin"
  username: "your-username" 
  password: "your-app-password"
```

## Usage

### Web Clipper API
After starting the add-on, Joplin Data API will be available on ports:

- 41184 - direct access (requires token)
- 41185 - through proxy (recommended)

### Management API
Management API is available on port 41186 and provides:

- `/token` - get API token
- `/sync` - trigger synchronization
- `/sync/status` - synchronization status
- `/info` - system information

### Automation Examples
Create note when door opens

```yaml
automation:
  - alias: "Door Alert to Joplin"
    trigger:
      platform: state
      entity_id: binary_sensor.front_door
      to: 'on'
    action:
      service: rest_command.joplin_note
      data:
        title: "🚪 Door opened"
        body: "Front door was opened at {{ now().strftime('%d.%m.%Y at %H:%M') }}"

rest_command:
  joplin_note:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}"
      }
```

Daily synchronization

```yaml
automation:
  - alias: "Daily Joplin Sync"
    trigger:
      platform: time
      at: "09:00:00"
    action:
      service: rest_command.joplin_sync

rest_command:
  joplin_sync:
    url: "http://localhost:41186/sync"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: '{"background": true}'
```

## Support
If you have issues with this add-on, please create an issue in the [GitHub repository](https://github.com/your-username/hassio-joplin-cli/issues).