#!/bin/bash
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting HA Joplin Bridge..."

# Check if bashio is available
if command -v bashio >/dev/null 2>&1; then
    log "Using bashio for configuration"
    # Get configuration from Home Assistant
    SYNC_TARGET=$(bashio::config 'sync_target' || echo "0")
    SYNC_INTERVAL=$(bashio::config 'sync_interval' || echo "300")
    LOCALE=$(bashio::config 'locale' || echo "en_GB")
    TIMEZONE=$(bashio::config 'timezone' || echo "UTC")
    ENABLE_ENCRYPTION=$(bashio::config 'enable_encryption' || echo "false")
    ENCRYPTION_PASSWORD=$(bashio::config 'encryption_password' || echo "")
    SYNC_SERVER_URL=$(bashio::config 'sync_config.server_url' || echo "")
    SYNC_USERNAME=$(bashio::config 'sync_config.username' || echo "")
    SYNC_PASSWORD=$(bashio::config 'sync_config.password' || echo "")
else
    log "Bashio not available, using defaults"
    SYNC_TARGET="0"
    SYNC_INTERVAL="300"
    LOCALE="en_GB"
    TIMEZONE="UTC"
    ENABLE_ENCRYPTION="false"
    ENCRYPTION_PASSWORD=""
    SYNC_SERVER_URL=""
    SYNC_USERNAME=""
    SYNC_PASSWORD=""
fi

log "Configuration loaded: sync_target=$SYNC_TARGET, locale=$LOCALE"

# Set timezone
export TZ=$TIMEZONE
if [ -f /usr/share/zoneinfo/$TZ ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
    log "Timezone set to $TZ"
fi

# Create directories and set permissions
mkdir -p /data/joplin/.config/joplin
chown -R joplin:joplin /data/joplin || true

log "Starting as joplin user..."

# Switch to joplin user and start services
su joplin -c "
export HOME=/data/joplin
cd /data/joplin

echo '[$(date +\"%Y-%m-%d %H:%M:%S\")] Configuring Joplin...'

# Create basic Joplin config
joplin config locale '$LOCALE'
joplin config sync.target $SYNC_TARGET
joplin config sync.interval $SYNC_INTERVAL

# Configure sync if needed
if [ '$SYNC_TARGET' -ne 0 ] && [ -n '$SYNC_SERVER_URL' ]; then
    echo '[$(date +\"%Y-%m-%d %H:%M:%S\")] Setting up sync...'
    if [ '$SYNC_TARGET' -eq 9 ]; then
        joplin config sync.9.path '$SYNC_SERVER_URL'
        [ -n '$SYNC_USERNAME' ] && joplin config sync.9.username '$SYNC_USERNAME'
        [ -n '$SYNC_PASSWORD' ] && joplin config sync.9.password '$SYNC_PASSWORD'
    elif [ '$SYNC_TARGET' -eq 5 ]; then
        joplin config sync.5.path '$SYNC_SERVER_URL'
        [ -n '$SYNC_USERNAME' ] && joplin config sync.5.username '$SYNC_USERNAME'
        [ -n '$SYNC_PASSWORD' ] && joplin config sync.5.password '$SYNC_PASSWORD'
    fi
fi

echo '[$(date +\"%Y-%m-%d %H:%M:%S\")] Starting Joplin server on port 41184...'
joplin server start --port 41184 &
JOPLIN_PID=\$!

# Wait for Joplin to start
sleep 5

echo '[$(date +\"%Y-%m-%d %H:%M:%S\")] Starting management API on port 41186...'
python3 /api_server.py &
API_PID=\$!

echo '[$(date +\"%Y-%m-%d %H:%M:%S\")] Services started - Joplin PID: \$JOPLIN_PID, API PID: \$API_PID'

# Wait for processes
wait \$JOPLIN_PID \$API_PID
"