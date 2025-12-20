# Multi-Tenant Configuration Guide

## Overview

Version 2.0.0 adds **multi-tenant** mode support, allowing multiple Home Assistant users to use their own Joplin accounts through a single addon.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Home Assistant Users                                       │
│  User1, User2, User3, User4                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │  Smart Proxy (Port 41185)     │
         │  - Automatic routing           │
         │  - Token-based profile mapping │
         └───────┬───────────────────────┘
                 │
    ┌────────────┼────────────┬────────────┐
    │            │            │            │
    ▼            ▼            ▼            ▼
┌─────────┐┌─────────┐┌─────────┐┌─────────┐
│ Joplin  ││ Joplin  ││ Joplin  ││ Joplin  │
│ CLI     ││ CLI     ││ CLI     ││ CLI     │
│ User1   ││ User2   ││ User3   ││ User4   │
│ :41184  ││ :41185  ││ :41186  ││ :41187  │
└─────────┘└─────────┘└─────────┘└─────────┘
```

## Configuration

### Example for 4 Users

```yaml
users:
  - name: "dad"
    sync_target: 9
    sync_server_url: "https://joplin.yourdomain.com"
    sync_username: "dad@family.com"
    sync_password: "password1"
    locale: "en_US"
    enable_encryption: true
    encryption_password: "encryption_pass1"
    
  - name: "mom"
    sync_target: 9
    sync_server_url: "https://joplin.yourdomain.com"
    sync_username: "mom@family.com"
    sync_password: "password2"
    locale: "en_US"
    enable_encryption: true
    encryption_password: "encryption_pass2"
    
  - name: "son"
    sync_target: 9
    sync_server_url: "https://joplin.yourdomain.com"
    sync_username: "son@family.com"
    sync_password: "password3"
    locale: "en_US"
    
  - name: "daughter"
    sync_target: 9
    sync_server_url: "https://joplin.yourdomain.com"
    sync_username: "daughter@family.com"
    sync_password: "password4"
    locale: "en_US"
```

### Minimal Configuration

```yaml
users:
  - name: "user1"
    sync_target: 0  # No sync
    
  - name: "user2"
    sync_target: 0
```

## Getting Tokens

### Option 1: Via Management API

```bash
curl http://localhost:41186/token
```

Response in multi-tenant mode:
```json
{
  "success": true,
  "mode": "multi-tenant",
  "users": {
    "dad": {
      "token": "abc123...",
      "joplin_data_api_url": "http://homeassistant.local:41185"
    },
    "mom": {
      "token": "def456...",
      "joplin_data_api_url": "http://homeassistant.local:41185"
    },
    "son": {
      "token": "ghi789...",
      "joplin_data_api_url": "http://homeassistant.local:41185"
    },
    "daughter": {
      "token": "jkl012...",
      "joplin_data_api_url": "http://homeassistant.local:41185"
    }
  }
}
```

## Home Assistant Integration

### Sensors for Each User

```yaml
sensor:
  # Tokens for all users
  - platform: rest
    name: joplin_tokens
    resource: http://localhost:41186/token
    value_template: "OK"
    json_attributes:
      - users
    scan_interval: 86400  # Once per day
  
  # Extract token for Dad
  - platform: template
    sensors:
      joplin_token_dad:
        value_template: "{{ state_attr('sensor.joplin_tokens', 'users')['dad']['token'] }}"
        
  # Extract token for Mom
  - platform: template
    sensors:
      joplin_token_mom:
        value_template: "{{ state_attr('sensor.joplin_tokens', 'users')['mom']['token'] }}"
        
  # Extract token for Son
  - platform: template
    sensors:
      joplin_token_son:
        value_template: "{{ state_attr('sensor.joplin_tokens', 'users')['son']['token'] }}"
        
  # Extract token for Daughter
  - platform: template
    sensors:
      joplin_token_daughter:
        value_template: "{{ state_attr('sensor.joplin_tokens', 'users')['daughter']['token'] }}"
```

### REST Commands for Each User

```yaml
rest_command:
  # Create note for Dad
  joplin_create_note_dad:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token_dad') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "parent_id": "{{ folder_id | default('') }}"
      }
      
  # Create note for Mom
  joplin_create_note_mom:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token_mom') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "parent_id": "{{ folder_id | default('') }}"
      }
      
  # Create note for Son
  joplin_create_note_son:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token_son') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "parent_id": "{{ folder_id | default('') }}"
      }
      
  # Create note for Daughter
  joplin_create_note_daughter:
    url: "http://localhost:41185/notes?token={{ states('sensor.joplin_token_daughter') }}"
    method: POST
    headers:
      Content-Type: "application/json"
    payload: >
      {
        "title": "{{ title }}",
        "body": "{{ body }}",
        "parent_id": "{{ folder_id | default('') }}"
      }
```

## Automation Examples

### Voice Notes for Each User

```yaml
automation:
  # Voice note for Dad
  - alias: "Voice Note for Dad"
    trigger:
      - platform: event
        event_type: mobile_app_notification_action
        event_data:
          action: "voice_note_dad"
    action:
      - service: rest_command.joplin_create_note_dad
        data:
          title: "🎤 Voice Note - {{ now().strftime('%d.%m %H:%M') }}"
          body: "{{ trigger.event.data.voice_text }}"
          
  # Voice note for Mom
  - alias: "Voice Note for Mom"
    trigger:
      - platform: event
        event_type: mobile_app_notification_action
        event_data:
          action: "voice_note_mom"
    action:
      - service: rest_command.joplin_create_note_mom
        data:
          title: "🎤 Voice Note - {{ now().strftime('%d.%m %H:%M') }}"
          body: "{{ trigger.event.data.voice_text }}"
```

### Personal Reminders

```yaml
automation:
  # Dad's trash reminder
  - alias: "Dad Trash Reminder"
    trigger:
      - platform: time
        at: "20:00:00"
    condition:
      - condition: time
        weekday: [sun]
    action:
      - service: rest_command.joplin_create_note_dad
        data:
          title: "🗑️ Reminder: Trash Collection"
          body: |
            Trash collection tomorrow morning!
            
            Don't forget:
            - Take out the bins
            - Check recycling sorting
            
  # Mom's shopping list
  - alias: "Shopping List for Mom"
    trigger:
      - platform: state
        entity_id: input_boolean.create_shopping_list
        to: 'on'
    action:
      - service: rest_command.joplin_create_note_mom
        data:
          title: "🛒 Shopping List - {{ now().strftime('%d.%m.%Y') }}"
          body: |
            {% for item in state_attr('sensor.shopping_items', 'items') %}
            - [ ] {{ item }}
            {% endfor %}
```

### Family Event Logger

```yaml
automation:
  # Log events from HA users
  - alias: "Family Event Logger"
    trigger:
      - platform: state
        entity_id: 
          - binary_sensor.front_door
          - binary_sensor.garage_door
    action:
      - choose:
          # If Dad arrived
          - conditions:
              - condition: state
                entity_id: person.dad
                state: 'just_arrived'
            sequence:
              - service: rest_command.joplin_create_note_dad
                data:
                  title: "🏠 Arrived Home - {{ now().strftime('%H:%M') }}"
                  body: "Door: {{ trigger.to_state.attributes.friendly_name }}"
                  
          # If Mom arrived
          - conditions:
              - condition: state
                entity_id: person.mom
                state: 'just_arrived'
            sequence:
              - service: rest_command.joplin_create_note_mom
                data:
                  title: "🏠 Arrived Home - {{ now().strftime('%H:%M') }}"
                  body: "Door: {{ trigger.to_state.attributes.friendly_name }}"
```

## Synchronization

### Manual Sync for Specific User

```bash
# Sync for Dad
curl -X POST http://localhost:41186/sync \
  -H "Content-Type: application/json" \
  -d '{"profile": "dad", "background": true}'

# Sync for Mom
curl -X POST http://localhost:41186/sync \
  -H "Content-Type: application/json" \
  -d '{"profile": "mom", "background": false}'
```

### Check Sync Status

```bash
# Status for all users
curl http://localhost:41186/sync/status

# Status for specific user
curl http://localhost:41186/sync/status?profile=dad
```

## Lovelace Dashboard

### Card for User Selection

```yaml
type: vertical-stack
cards:
  - type: markdown
    content: |
      ## 📝 Create Note
      
  - type: entities
    entities:
      - input_select.joplin_user
      - input_text.joplin_note_title
      - input_text.joplin_note_body
      
  - type: button
    name: Create Note
    tap_action:
      action: call-service
      service: script.create_joplin_note_for_user
```

### Script for Dynamic User Selection

```yaml
input_select:
  joplin_user:
    name: Joplin User
    options:
      - Dad
      - Mom
      - Son
      - Daughter

input_text:
  joplin_note_title:
    name: Title
    
  joplin_note_body:
    name: Note Body
    mode: text

script:
  create_joplin_note_for_user:
    sequence:
      - choose:
          - conditions:
              - condition: state
                entity_id: input_select.joplin_user
                state: 'Dad'
            sequence:
              - service: rest_command.joplin_create_note_dad
                data:
                  title: "{{ states('input_text.joplin_note_title') }}"
                  body: "{{ states('input_text.joplin_note_body') }}"
                  
          - conditions:
              - condition: state
                entity_id: input_select.joplin_user
                state: 'Mom'
            sequence:
              - service: rest_command.joplin_create_note_mom
                data:
                  title: "{{ states('input_text.joplin_note_title') }}"
                  body: "{{ states('input_text.joplin_note_body') }}"
                  
          - conditions:
              - condition: state
                entity_id: input_select.joplin_user
                state: 'Son'
            sequence:
              - service: rest_command.joplin_create_note_son
                data:
                  title: "{{ states('input_text.joplin_note_title') }}"
                  body: "{{ states('input_text.joplin_note_body') }}"
                  
          - conditions:
              - condition: state
                entity_id: input_select.joplin_user
                state: 'Daughter'
            sequence:
              - service: rest_command.joplin_create_note_daughter
                data:
                  title: "{{ states('input_text.joplin_note_title') }}"
                  body: "{{ states('input_text.joplin_note_body') }}"
```

## Migration from Single-User to Multi-Tenant

If you're already using version 1.x in single-user mode:

1. **Backup your data** - it's located in `/data/joplin`
2. **Update configuration** by adding `users` array
3. **Restart addon**
4. **Update sensors and commands** in Home Assistant

### Backward Compatibility

The addon will continue to work in legacy single-user mode if the `users` array is empty:

```yaml
# Legacy mode (as before)
sync_target: 9
sync_server_url: "https://joplin.example.com"
sync_username: "user@example.com"
sync_password: "password"
users: []  # Empty array = legacy mode
```

## Limitations

- Maximum 10 users (technically more is possible, but RAM usage increases)
- Each Joplin profile uses ~50-100MB RAM
- All users must use the same sync type (or no sync)

## Troubleshooting

### Check Operating Mode

```bash
curl http://localhost:41186/health
```

Response will show operating mode:
```json
{
  "status": "healthy",
  "mode": "multi",
  "users_count": 4,
  "addon_version": "2.0.0"
}
```

### Check All Joplin CLI Instances Running

```bash
curl http://localhost:41186/info
```

### Logs

Check addon logs in Home Assistant:
- Settings → Add-ons → HA Joplin Bridge → Logs

You should see:
```
Multi-user mode detected: 4 users
Setting up user 1/4: dad
Starting Joplin server for dad on localhost:41184
...
Multi-tenant proxy active on port 41185
```

## FAQ

**Q: Can I use different Joplin Server accounts?**  
A: Yes! Each user can have their own Joplin Server account.

**Q: Can I add a user without restarting?**  
A: No, addon restart is required to apply configuration changes.

**Q: How do I remove a user?**  
A: Remove them from the `users` array in configuration and restart the addon. Data will remain in `/data/joplin/profiles/username`.

**Q: Is this secure?**  
A: Yes, each user has an isolated profile and unique token. The proxy automatically routes requests to the correct profile.

**Q: Can users have different sync services?**  
A: Currently all users should use the same sync target type (0, 5, 8, or 9). Support for mixed sync targets may come in a future version.
