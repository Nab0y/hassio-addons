#!/usr/bin/with-contenv bashio
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Get configuration from Home Assistant
SYNC_TARGET=$(bashio::config 'sync_target')
SYNC_INTERVAL=$(bashio::config 'sync_interval')
LOCALE=$(bashio::config 'locale')
TIMEZONE=$(bashio::config 'timezone')
ENABLE_ENCRYPTION=$(bashio::config 'enable_encryption')
ENCRYPTION_PASSWORD=$(bashio::config 'encryption_password')

# Parse sync settings
if bashio::config.exists 'sync_config.server_url'; then
    SYNC_SERVER_URL=$(bashio::config 'sync_config.server_url')
else
    SYNC_SERVER_URL=""
fi

if bashio::config.exists 'sync_config.username'; then
    SYNC_USERNAME=$(bashio::config 'sync_config.username')
else
    SYNC_USERNAME=""
fi

if bashio::config.exists 'sync_config.password'; then
    SYNC_PASSWORD=$(bashio::config 'sync_config.password')
else
    SYNC_PASSWORD=""
fi

log "Starting HA Joplin Bridge..."
log "Sync target: $SYNC_TARGET, Locale: $LOCALE, Timezone: $TIMEZONE"

# Set timezone
export TZ=$TIMEZONE
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create directories and set permissions
mkdir -p /data/joplin/.config/joplin
chown -R joplin:joplin /data/joplin

# Switch to joplin user
su joplin -c '
export HOME=/data/joplin
cd /data/joplin

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Creating Joplin configuration..."
cat > joplin-config.json << EOF
{
    "locale": "'$LOCALE'",
    "sync.target": '$SYNC_TARGET',
    "sync.interval": '$SYNC_INTERVAL',
    "dateFormat": "DD/MM/YYYY",
    "timeFormat": "HH:mm",
    "trackLocation": true,
    "revisionService.enabled": true,
    "revisionService.ttlDays": 90,
    "showCompletedTodos": true,
    "uncompletedTodosOnTop": true,
    "sync.wipeOutFailSafe": true,
    "sync.maxConcurrentConnections": 5,
    "clipperServer.autoStart": true
}
EOF

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Importing configuration..."
joplin config --import < joplin-config.json

# Configure sync settings
if [ '$SYNC_TARGET' -ne 0 ] && [ -n "'$SYNC_SERVER_URL'" ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Configuring sync settings..."
    
    if [ '$SYNC_TARGET' -eq 9 ]; then
        # Joplin Server
        joplin config sync.9.path "'$SYNC_SERVER_URL'"
        [ -n "'$SYNC_USERNAME'" ] && joplin config sync.9.username "'$SYNC_USERNAME'"
        [ -n "'$SYNC_PASSWORD'" ] && joplin config sync.9.password "'$SYNC_PASSWORD'"
    elif [ '$SYNC_TARGET' -eq 5 ]; then
        # WebDAV/Nextcloud
        joplin config sync.5.path "'$SYNC_SERVER_URL'"
        [ -n "'$SYNC_USERNAME'" ] && joplin config sync.5.username "'$SYNC_USERNAME'"
        [ -n "'$SYNC_PASSWORD'" ] && joplin config sync.5.password "'$SYNC_PASSWORD'"
    fi
    
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Sync settings configured"
fi

# Enable encryption if needed
if [ "'$ENABLE_ENCRYPTION'" = "true" ] && [ -n "'$ENCRYPTION_PASSWORD'" ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Enabling end-to-end encryption..."
    echo "'$ENCRYPTION_PASSWORD'" | joplin e2ee enable --password-stdin
fi

# Run initial sync if configured
if [ '$SYNC_TARGET' -ne 0 ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Running initial sync..."
    joplin sync || echo "Initial sync failed, continuing..."
fi

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Starting Joplin server..."
# Start Joplin server in background
nohup joplin server start > /data/joplin/joplin.log 2>&1 &

# Wait for Joplin to start
sleep 5

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Starting management API server..."
# Start API server in background
nohup python3 /api_server.py > /data/joplin/api.log 2>&1 &

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Starting port forwarder..."
'

# Start socat proxy for port forwarding
log "Starting socat proxy on port 41185..."
socat TCP-LISTEN:41185,fork,bind=0.0.0.0 TCP:127.0.0.1:41184