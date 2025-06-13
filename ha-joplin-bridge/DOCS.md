# Documentation: Joplin CLI Add-on

## Introduction

Joplin CLI Add-on provides full access to Joplin from Home Assistant through Web Clipper API and additional Management API.

## API Reference

### Web Clipper API (port 41185)

Standard Joplin Data API for working with notes, notebooks and tags.

**Base URL:** `http://localhost:41185`

#### Main endpoints:

- `GET /ping` - health check
- `GET /folders` - list notebooks
- `GET /notes` - list notes
- `POST /notes` - create note
- `PUT /notes/{id}` - update note
- `DELETE /notes/{id}` - delete note

**Examples:**

```bash
# Get list of notebooks
curl "http://localhost:41185/folders?token=YOUR_TOKEN"

# Create note
curl -X POST "http://localhost:41185/notes?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "New note",
    "body": "Note content"
  }'
```

### Management API (port 41186)

Additional API for managing the add-on.

**Base URL:** `http://localhost:41186`

#### Endpoints:

- `GET /health` - Check add-on status.

**Response:**

```json
{
  "status": "healthy",
  "joplin_api_available": true,
  "sync_running": false,
  "addon_version": "1.0.0"
}
```

- `GET /token` - Get API token for Web Clipper API.

**Response:**

```json
{
  "success": true,
  "token": "your-api-token",
  "joplin_data_api_url": "http://your-host:41185"
}
```

- `POST /sync` - tart synchronization.

**Parameters:**

```json
{
  "background": true  // true for background sync
}
```

- `GET /sync/status` - Get synchronization status.

**Response:**

```json
{
  "success": true,
  "status": {
    "running": false,
    "last_sync": "2024-01-01T12:00:00.000000",
    "error": null,
    "output": "Sync completed successfully"
  }
}
```


## Sync Configuration

### Joplin Server
```yaml
sync_target: 9
sync_config:
  server_url: "https://your-joplin-server.com"
  username: "user@example.com"
  password: "password"
```

### Nextcloud
```yaml
sync_target: 5
sync_config:
  server_url: "https://cloud.example.com/remote.php/dav/files/username/Joplin"
  username: "username"
  password: "app-password"
```

## Home Assistant Automations

### Token sensor
```yaml
sensor:
  - platform: rest
    name: joplin_token
    resource: http://localhost:41186/token
    value_template: "{{ value_json.token }}"
    scan_interval: 3600
```

### Sync status sensor
```yaml
sensor:
  - platform: rest
    name: joplin_sync_status
    resource: http://localhost:41186/sync/status
    value_template: >
      {% if value_json.status.running %}
        Syncing...
      {% elif value_json.status.last_sync %}
        {{ as_timestamp(value_json.status.last_sync) | timestamp_custom('%d.%m %H:%M') }}
      {% else %}
        Never
      {% endif %}
    json_attributes:
      - status
```