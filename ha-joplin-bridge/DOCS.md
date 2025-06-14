# Documentation: HA Joplin Bridge Add-on

## Introduction

HA Joplin Bridge Add-on creates a powerful integration between Home Assistant and Joplin note-taking application. It runs Joplin CLI inside a containerized environment and provides two APIs:

- **Joplin Web Clipper API** (port 41185) - Standard Joplin REST API for managing notes, notebooks, and tags
- **Management API** (port 41186) - Additional control interface for monitoring and managing the add-on

This integration enables you to create sophisticated home automation workflows that can log events, generate reports, and maintain detailed records of your smart home activities.

## Architecture Overview

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│   Home Assistant    │    │    HA Joplin Bridge  │    │   External Sync     │
│                     │    │                      │    │                     │
│  Automations    ────┼────┼──► Management API    │    │  ◦ Joplin Server    │
│  REST Commands      │    │      (Port 41186)    │    │  ◦ Nextcloud        │
│  Sensors            │    │                      │    │  ◦ OneDrive         │
│                     │    │  ┌─────────────────┐ │    │  ◦ Dropbox          │
│                     │    │  │  Joplin CLI     │ │◄───┼──► ◦ S3 Compatible  │
│  Dashboard      ────┼────┼──► Web Clipper API │ │    │  ◦ Local Files      │
│  Notifications      │    │  │  (Port 41185)   │ │    │                     │
│                     │    │  └─────────────────┘ │    │                     │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
```

## API Reference

### 🌐 Joplin Web Clipper API (Port 41185)

This is the standard Joplin Data API that provides full access to your notes, notebooks, and tags. All requests require an authentication token.

**Base URL:** `http://localhost:41185`

**Authentication:** All endpoints require `?token=YOUR_TOKEN` parameter.

#### Core Endpoints

##### 📌 Health Check
- **GET** `/ping` - Verify API is responding

**Example:**
```bash
curl "http://localhost:41185/ping?token=YOUR_TOKEN"
# Response: "JoplinClipperServer"
```

##### 📁 Notebooks (Folders)
- **GET** `/folders` - List all notebooks
- **GET** `/folders/{id}` - Get specific notebook
- **POST** `/folders` - Create new notebook
- **PUT** `/folders/{id}` - Update notebook
- **DELETE** `/folders/{id}` - Delete notebook

**Examples:**
```bash
# List all notebooks
curl "http://localhost:41185/folders?token=YOUR_TOKEN"

# Create a new notebook
curl -X POST "http://localhost:41185/folders?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Home Assistant Logs"}'

# Get specific notebook
curl "http://localhost:41185/folders/FOLDER_ID?token=YOUR_TOKEN"
```

##### 📝 Notes
- **GET** `/notes` - List all notes
- **GET** `/notes/{id}` - Get specific note
- **POST** `/notes` - Create new note
- **PUT** `/notes/{id}` - Update note
- **DELETE** `/notes/{id}` - Delete note

**Examples:**
```bash
# List all notes
curl "http://localhost:41185/notes?token=YOUR_TOKEN"

# Create a note (requires parent_id for notebook)
curl -X POST "http://localhost:41185/notes?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Security Alert",
    "body": "Front door opened at 15:30",
    "parent_id": "FOLDER_ID"
  }'

# Update a note
curl -X PUT "http://localhost:41185/notes/NOTE_ID?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Security Alert",
    "body": "Front door opened at 15:30\nAlarm was set"
  }'

# Get note content
curl "http://localhost:41185/notes/NOTE_ID?token=YOUR_TOKEN"
```

##### 🏷️ Tags
- **GET** `/tags` - List all tags
- **GET** `/tags/{id}` - Get specific tag
- **POST** `/tags` - Create new tag
- **POST** `/tags/{id}/notes` - Add tag to note
- **DELETE** `/tags/{id}/notes/{note_id}` - Remove tag from note

**Examples:**
```bash
# List all tags
curl "http://localhost:41185/tags?token=YOUR_TOKEN"

# Create a tag
curl -X POST "http://localhost:41185/tags?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "home-automation"}'

# Add tag to note
curl -X POST "http://localhost:41185/tags/TAG_ID/notes?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "NOTE_ID"}'
```

#### Query Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `fields` | Limit returned fields | `?fields=id,title,updated_time` |
| `page` | Page number for pagination | `?page=1` |
| `limit` | Number of items per page | `?limit=10` |
| `order_by` | Sort field | `?order_by=updated_time` |
| `order_dir` | Sort direction | `?order_dir=DESC` |

**Example with query parameters:**
```bash
curl "http://localhost:41185/notes?token=YOUR_TOKEN&fields=id,title&limit=5&order_by=updated_time&order_dir=DESC"
```

### 🔧 Management API (Port 41186)

This API provides additional functionality for managing the add-on itself, including sync control and system monitoring.

**Base URL:** `http://localhost:41186`

**Authentication:** No authentication required (internal network only).

#### Endpoints

##### 🏥 Health Check
**GET** `/health` - Check add-on health and status

**Response:**
```json
{
  "status": "healthy",
  "joplin_api_available": true,
  "sync_running": false,
  "addon_version": "1.0.8"
}
```

##### 🔑 Token Management
**GET** `/token` - Get Joplin API token and connection info

**Response:**
```json
{
  "success": true,
  "token": "9e7ae3f48344b48dcab49953e5470858f3e083a65f41b6c8583f2e387907ec6b03d383bd9edd8e3bb7a3a8cc9dffc9ca50ccbf2a0fba75c9c47c108e07981516",
  "joplin_data_api_url": "http://your-host:41185"
}
```

##### 🔄 Synchronization Control
**POST** `/sync` - Start synchronization with configured service

**Request Body:**
```json
{
  "background": true  // Optional: true for background sync, false for blocking
}
```

**Response (Background sync):**
```json
{
  "success": true,
  "message": "Background sync started",
  "status": {
    "running": true,
    "last_sync": null,
    "error": null,
    "output": null
  }
}
```

**Response (Foreground sync):**
```json
{
  "success": true,
  "message": "Sync completed",
  "output": "Synchronisation target: Joplin Server...\nStarting synchronisation...\nCompleted: 15/04/2024 10:30",
  "error": null,
  "status": {
    "running": false,
    "last_sync": "2024-04-15T10:30:00.000000",
    "error": null,
    "output": "Sync completed successfully"
  }
}
```

##### 📊 Sync Status
**GET** `/sync/status` - Get current synchronization status

**Response:**
```json
{
  "success": true,
  "status": {
    "running": false,
    "last_sync": "2024-04-15T10:30:00.000000",
    "error": null,
    "output": "Synchronisation completed successfully"
  }
}
```

##### ℹ️ System Information
**GET** `/info` - Get comprehensive system information

**Response:**
```json
{
  "success": true,
  "addon_version": "1.0.8",
  "joplin_version": "CLI",
  "status": "Profile created successfully",
  "sync_target": "9",
  "sync_status": {
    "running": false,
    "last_sync": "2024-04-15T10:30:00.000000",
    "error": null,
    "output": "Sync completed successfully"
  },
  "api_endpoints": {
    "token": "/token",
    "health": "/health",
    "info": "/info",
    "sync": "/sync (POST)",
    "sync_status": "/sync/status"
  },
  "joplin_data_api_url": "http://your-host:41185"
}
```

## Configuration Reference

### Synchronization Targets

| Value | Service | Description |
|-------|---------|-------------|
| `0` | None | No synchronization |
| `2` | File System | Local file system sync |
| `3` | OneDrive | Microsoft OneDrive |
| `5` | Nextcloud/WebDAV | Nextcloud or any WebDAV server |
| `7` | Dropbox | Dropbox cloud storage |
| `8` | S3 Compatible | Amazon S3 or compatible storage |
| `9` | Joplin Server | Dedicated Joplin Server |
| `10` | Joplin Cloud | Official Joplin Cloud service |

### Configuration Examples

#### Joplin Server Configuration
```yaml
sync_target: 9
sync_server_url: "https://joplin.yourdomain.com"
sync_username: "your-email@example.com"
sync_password: "your-password"
enable_encryption: true
encryption_password: "your-encryption-password"
```

#### Nextcloud Configuration
```yaml
sync_target: 5
sync_server_url: "https://cloud.example.com/remote.php/dav/files/username/Joplin"
sync_username: "your-username"
sync_password: "your-app-password"  # Use app password, not account password
locale: "en_US"
timezone: "America/New_York"
```

#### OneDrive Configuration
```yaml
sync_target: 3
# OneDrive uses OAuth, no username/password needed
```

#### Local File System (No External Sync)
```yaml
sync_target: 0
locale: "en_GB"
timezone: "UTC"
sync_interval: 300
```

## Home Assistant Integration

### 📊 Sensors Configuration

Add these sensors to your `configuration.yaml` to monitor the add-on:

```yaml
sensor:
  # Joplin API Token (persistent across restarts)
  - platform: rest
    name: joplin_token
    resource: http://localhost:41186/token
    value_template: "{{ value_json.token }}"
    scan_interval: 86400  # Check once per day (token persists)
    json_attributes:
      - joplin_data_api_url
    
  # Sync Status Monitor
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
    scan_interval: 60
    json_attributes:
      - status
      
  # Add-on Health Monitor
  - platform: rest
    name: joplin_health
    resource: http://localhost:41186/health
    value_template: "{{ value_json.status }}"
    scan_interval: 300
    json_attributes:
      - joplin_api_available
      - sync_running
      - addon_version
      
  # Notes Count (requires valid token)
  - platform: rest
    name: joplin_notes_count
    resource_template: "http://localhost:41185/notes?token={{ states('sensor.joplin_token') }}&fields=id"
    value_template: "{{ value_json | length }}"
    scan_interval: 1800  # Check every 30 minutes
    
  # Notebooks Count
  - platform: rest
    name: joplin_notebooks_count
    resource_template: "http://localhost:41185/folders?token={{ states('sensor.joplin_token') }}&fields=id"
    value_template: "{{ value_json | length }}"
    scan_interval: 3600  # Check every hour
```

### 🚀 REST Commands

```yaml
rest_command:
  # Create a new note
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
      
  # Create a new notebook
  joplin_create_notebook:
    url: "http://localhost:41185/folders?token={{ states('sensor.joplin_token') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}"
      }
      
  # Update existing note
  joplin_update_note:
    url: "http://localhost:41185/notes/{{ note_id }}?token={{ states('sensor.joplin_token') }}"
    method: PUT
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title | default('') }}",
        "body": "{{ body | default('') }}"
      }
      
  # Trigger synchronization
  joplin_sync:
    url: "http://localhost:41186/sync"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: '{"background": true}'
    
  # Create note with tag
  joplin_create_tagged_note:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "parent_id": "{{ folder_id }}",
        "tags": "{{ tags | default('') }}"
      }
```

### 📝 Advanced Automation Examples

#### Smart Home Event Logger
```yaml
automation:
  - alias: "Log Security Events to Joplin"
    trigger:
      - platform: state
        entity_id: 
          - binary_sensor.front_door
          - binary_sensor.back_door
          - binary_sensor.garage_door
        to: 'on'
      - platform: state
        entity_id: alarm_control_panel.home
        to: 'triggered'
    action:
      - service: rest_command.joplin_create_note
        data:
          title: >
            🚨 {{ trigger.to_state.attributes.friendly_name }} - {{ now().strftime('%H:%M:%S') }}
          body: |
            # Security Event Log
            
            **Device:** {{ trigger.to_state.attributes.friendly_name }}
            **Event:** {{ trigger.from_state.state }} → {{ trigger.to_state.state }}
            **Timestamp:** {{ now().strftime('%d.%m.%Y at %H:%M:%S') }}
            **Entity ID:** `{{ trigger.entity_id }}`
            
            {% if trigger.entity_id == 'alarm_control_panel.home' %}
            ## 🚨 SECURITY ALERT
            
            The alarm system has been triggered! Immediate attention required.
            
            ### System Status:
            {% for entity in states.sensor if 'alarm' in entity.entity_id %}
            - {{ entity.attributes.friendly_name }}: {{ entity.state }}
            {% endfor %}
            {% else %}
            ## 🚪 Door Activity
            
            Regular door activity detected.
            {% endif %}
            
            ### House Status at Time of Event:
            - Alarm State: {{ states('alarm_control_panel.home') }}
            - People Home: {{ states.device_tracker | selectattr('state', 'eq', 'home') | list | count }}
            - Temperature: {{ states('sensor.indoor_temperature') }}°C
            - Lights On: {{ states.light | selectattr('state', 'eq', 'on') | list | count }}
            
            ---
            *Logged automatically by Home Assistant*
          folder_id: "YOUR_SECURITY_NOTEBOOK_ID"
```

#### Weekly Home Report Generator
```yaml
automation:
  - alias: "Generate Weekly Home Report"
    trigger:
      platform: time
      at: "08:00:00"
    condition:
      condition: time
      weekday: [sun]
    action:
      - service: rest_command.joplin_create_note
        data:
          title: "📊 Weekly Home Report - {{ now().strftime('%d.%m.%Y') }}"
          body: |
            # Smart Home Weekly Summary
            **Report Period:** {{ (now() - timedelta(days=7)).strftime('%d.%m') }} - {{ now().strftime('%d.%m.%Y') }}
            
            ## 🏠 General Statistics
            - **Uptime:** {{ states('sensor.uptime') }}
            - **Home Assistant Version:** {{ states('sensor.current_version') }}
            - **Add-ons Active:** {{ states.sensor | selectattr('entity_id', 'search', 'addon_') | selectattr('state', 'eq', 'started') | list | count }}
            
            ## 🌡️ Climate Control
            - **Average Indoor Temperature:** {{ states('sensor.average_temperature') }}°C
            - **Average Humidity:** {{ states('sensor.average_humidity') }}%
            - **Heating Hours This Week:** {{ states('sensor.heating_hours_week') }}h
            - **Cooling Hours This Week:** {{ states('sensor.cooling_hours_week') }}h
            
            ## ⚡ Energy Management
            - **Total Energy Consumption:** {{ states('sensor.energy_total_week') }} kWh
            - **Solar Generation:** {{ states('sensor.solar_total_week') }} kWh
            - **Grid Import:** {{ states('sensor.grid_import_week') }} kWh
            - **Estimated Cost:** ${{ (states('sensor.energy_total_week') | float * 0.12) | round(2) }}
            
            ## 🚪 Security & Access
            - **Door Openings:** {{ states('counter.door_openings_week') }}
            - **Motion Detections:** {{ states('counter.motion_detections_week') }}
            - **Security Alerts:** {{ states('counter.security_alerts_week') }}
            - **Unknown Devices:** {{ states('counter.unknown_devices_week') }}
            
            ## 📱 Device Status
            ### Online Devices
            {% for device in states.device_tracker if device.state == 'home' %}
            - {{ device.attributes.friendly_name }}: Connected
            {% endfor %}
            
            ### Battery Levels
            {% for entity in states.sensor if 'battery' in entity.entity_id and entity.state | int < 20 %}
            - ⚠️ {{ entity.attributes.friendly_name }}: {{ entity.state }}%
            {% endfor %}
            
            ## 🔧 Maintenance Reminders
            {% if states('sensor.air_filter_days') | int > 90 %}
            - 🔴 Replace air filter ({{ states('sensor.air_filter_days') }} days)
            {% endif %}
            {% if states('sensor.water_filter_days') | int > 180 %}
            - 🔴 Replace water filter ({{ states('sensor.water_filter_days') }} days)
            {% endif %}
            
            ## 📈 Trends & Insights
            - **Most Active Hour:** {{ states('sensor.most_active_hour') }}
            - **Peak Energy Usage:** {{ states('sensor.peak_energy_time') }}
            - **Busiest Day:** {{ states('sensor.busiest_day_week') }}
            
            ---
            *Report generated automatically on {{ now().strftime('%d.%m.%Y at %H:%M') }}*
            *Next report: {{ (now() + timedelta(days=7)).strftime('%d.%m.%Y') }}*
          folder_id: "YOUR_REPORTS_NOTEBOOK_ID"
```

#### Dynamic Note Updates
```yaml
automation:
  - alias: "Update Daily Log with Activities"
    trigger:
      - platform: state
        entity_id: sensor.daily_log_note_id
    action:
      - service: rest_command.joplin_update_note
        data:
          note_id: "{{ states('sensor.daily_log_note_id') }}"
          body: |
            # Daily Activity Log - {{ now().strftime('%d.%m.%Y') }}
            
            ## Morning Routine
            {% if states('input_boolean.morning_routine_complete') == 'on' %}
            - ✅ Morning routine completed at {{ states('sensor.morning_routine_time') }}
            {% else %}
            - ⏳ Morning routine pending
            {% endif %}
            
            ## Energy Usage Today
            - Current consumption: {{ states('sensor.power_consumption') }}W
            - Total today: {{ states('sensor.energy_today') }} kWh
            
            ## Security Status
            - Alarm: {{ states('alarm_control_panel.home') }}
            - Last door activity: {{ states('sensor.last_door_activity') }}
            
            ## Weather
            - Temperature: {{ states('weather.home') }}°C
            - Condition: {{ state_attr('weather.home', 'condition') }}
            
            ---
            *Last updated: {{ now().strftime('%H:%M:%S') }}*
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### 1. **API Not Responding**
**Symptoms:** `curl: (7) Failed to connect`

**Solutions:**
```bash
# Check if add-on is running
# In Home Assistant: Settings → Add-ons → HA Joplin Bridge → should show "Started"

# Test from Home Assistant terminal
curl http://localhost:41186/health

# Check add-on logs
# Settings → Add-ons → HA Joplin Bridge → Logs
```

#### 2. **Token Issues**
**Symptoms:** `{"error": "Invalid token"}`

**Solutions:**
```bash
# Get fresh token
curl http://localhost:41186/token

# Verify token in sensor
# Developer Tools → States → sensor.joplin_token
```

#### 3. **Sync Failures**
**Symptoms:** Sync status shows errors

**Solutions:**
```bash
# Check sync status
curl http://localhost:41186/sync/status

# Common fixes:
# - Verify server_url is accessible
# - Check username/password
# - Ensure network connectivity
# - Check firewall settings
```

#### 4. **Note Creation Fails**
**Symptoms:** `{"error": "Cannot find folder for note"}`

**Solutions:**
```bash
# Create a notebook first
curl -X POST "http://localhost:41185/folders?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Home Assistant"}'

# Then create note with parent_id
curl -X POST "http://localhost:41185/notes?token=YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Note",
    "body": "Content",
    "parent_id": "FOLDER_ID_FROM_ABOVE"
  }'
```

#### 5. **Automation Not Working**
**Common issues:**
- Wrong port numbers in URLs
- Missing or incorrect token
- Invalid JSON in payload
- Network accessibility issues

**Debug steps:**
```yaml
# Add logging to automation
- service: system_log.write
  data:
    message: "Joplin automation triggered with data: {{ title }}"
    level: info
```

### Performance Optimization

#### Sensor Scan Intervals
Adjust based on your needs:
```yaml
sensor:
  - platform: rest
    name: joplin_token
    scan_interval: 86400  # Once per day (token persists)
    
  - platform: rest
    name: joplin_sync_status
    scan_interval: 300    # Every 5 minutes
    
  - platform: rest
    name: joplin_notes_count
    scan_interval: 3600   # Every hour
```

#### API Rate Limiting
- Avoid making rapid successive API calls
- Use background sync for regular synchronization
- Batch note creation when possible

## 🔐 Security Best Practices

### Network Security
- Add-on APIs are only accessible within Home Assistant network
- Use HTTPS for external sync services
- Regularly update sync service passwords

### Data Protection
- Enable end-to-end encryption for sensitive notes
- Use app passwords for Nextcloud/WebDAV
- Regularly backup Joplin data

### Access Control
- API tokens persist but are unique per installation
- Monitor API access through Home Assistant logs
- Use least-privilege principle for sync accounts

## 📚 Advanced Topics

### Custom Integrations

#### Node-RED Integration
Create flows that interact with Joplin for complex automation scenarios.

#### AppDaemon Integration
Use AppDaemon apps to create sophisticated note management workflows.

#### Custom Components
Develop Home Assistant custom components that integrate with the Joplin APIs.

### Backup and Recovery

#### Automated Backups
```yaml
automation:
  - alias: "Weekly Joplin Backup"
    trigger:
      platform: time
      at: "03:00:00"
    condition:
      condition: time
      weekday: [sun]
    action:
      - service: rest_command.joplin_sync
      - delay: "00:05:00"
      - service: shell_command.backup_joplin_data
```

#### Data Migration
- Export notes before major updates
- Test sync configuration in staging environment
- Maintain external backups of critical notes

### Integration Examples

#### Smart Doorbell Notes
Log visitor information automatically when doorbell is pressed.

#### Weather Journaling
Create daily weather notes with conditions and alerts.

#### Device Maintenance Tracking
Automatically log device battery changes and maintenance activities.

## 📖 Related Resources

- [Joplin API Documentation](https://joplinapp.org/api/references/rest_api/)
- [Home Assistant REST Integration](https://www.home-assistant.io/integrations/rest/)
- [Home Assistant Automation](https://www.home-assistant.io/docs/automation/)
- [YAML Configuration](https://www.home-assistant.io/docs/configuration/yaml/)

---

*This documentation is maintained as part of the HA Joplin Bridge add-on project. For updates and contributions, visit the [GitHub repository](https://github.com/Nab0y/hassio-addons).*