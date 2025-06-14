#!/bin/bash
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting HA Joplin Bridge..."

# Read configuration from options file (Home Assistant way)
if [ -f /data/options.json ]; then
    log "Reading configuration from /data/options.json"
    SYNC_TARGET=$(jq -r '.sync_target // 0' /data/options.json)
    SYNC_INTERVAL=$(jq -r '.sync_interval // 300' /data/options.json)
    LOCALE=$(jq -r '.locale // "en_GB"' /data/options.json)
    TIMEZONE=$(jq -r '.timezone // "UTC"' /data/options.json)
    ENABLE_ENCRYPTION=$(jq -r '.enable_encryption // false' /data/options.json)
    ENCRYPTION_PASSWORD=$(jq -r '.encryption_password // ""' /data/options.json)
    SYNC_SERVER_URL=$(jq -r '.sync_server_url // ""' /data/options.json)
    SYNC_USERNAME=$(jq -r '.sync_username // ""' /data/options.json)
    SYNC_PASSWORD=$(jq -r '.sync_password // ""' /data/options.json)
else
    log "No options.json found, using defaults"
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

log "Configuration: sync_target=$SYNC_TARGET, locale=$LOCALE, timezone=$TIMEZONE"

# Set timezone
export TZ=$TIMEZONE
if [ -f /usr/share/zoneinfo/$TZ ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
    log "Timezone set to $TZ"
fi

# Create directories and set permissions
mkdir -p /data/joplin/.config/joplin
chown -R joplin:joplin /data/joplin 2>/dev/null || true

log "Starting services as joplin user..."

# Configure Joplin as joplin user
su joplin -c '
export HOME=/data/joplin
cd /data/joplin

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Configuring Joplin..."

# Create basic Joplin config
joplin config locale "'"$LOCALE"'" 2>/dev/null || true
joplin config sync.target '"$SYNC_TARGET"' 2>/dev/null || true
joplin config sync.interval '"$SYNC_INTERVAL"' 2>/dev/null || true

# Configure sync if needed
if [ '"$SYNC_TARGET"' -ne 0 ] && [ "'"$SYNC_SERVER_URL"'" != "null" ] && [ -n "'"$SYNC_SERVER_URL"'" ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Setting up sync for target '"$SYNC_TARGET"'..."
    if [ '"$SYNC_TARGET"' -eq 9 ]; then
        joplin config sync.9.path "'"$SYNC_SERVER_URL"'" 2>/dev/null || true
        [ "'"$SYNC_USERNAME"'" != "null" ] && [ -n "'"$SYNC_USERNAME"'" ] && joplin config sync.9.username "'"$SYNC_USERNAME"'" 2>/dev/null || true
        [ "'"$SYNC_PASSWORD"'" != "null" ] && [ -n "'"$SYNC_PASSWORD"'" ] && joplin config sync.9.password "'"$SYNC_PASSWORD"'" 2>/dev/null || true
    elif [ '"$SYNC_TARGET"' -eq 5 ]; then
        joplin config sync.5.path "'"$SYNC_SERVER_URL"'" 2>/dev/null || true
        [ "'"$SYNC_USERNAME"'" != "null" ] && [ -n "'"$SYNC_USERNAME"'" ] && joplin config sync.5.username "'"$SYNC_USERNAME"'" 2>/dev/null || true
        [ "'"$SYNC_PASSWORD"'" != "null" ] && [ -n "'"$SYNC_PASSWORD"'" ] && joplin config sync.5.password "'"$SYNC_PASSWORD"'" 2>/dev/null || true
    fi
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Sync configuration completed"
fi
'

log "Starting Joplin server on localhost..."
# Start Joplin server as joplin user (only on localhost for security)
su joplin -c 'export HOME=/data/joplin; cd /data/joplin; joplin server start --port 41184 --host 127.0.0.1' &
JOPLIN_PID=$!

# Wait for Joplin to start
sleep 10

log "Starting socat proxy for Joplin API..."
# Start socat proxy to forward external requests to localhost Joplin
socat TCP-LISTEN:41185,fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:41184 &
SOCAT_PID=$!

log "Starting management API server..."
# Start API server as root (needs access to ports)
python3 /api_server.py &
API_PID=$!

log "All services started successfully"
log "Joplin PID: $JOPLIN_PID, Socat PID: $SOCAT_PID, API PID: $API_PID"
log "Auto-sync configured: sync_target=$SYNC_TARGET, interval=${SYNC_INTERVAL}s"

# Cleanup function
cleanup() {
    log "Shutting down services..."
    kill $API_PID 2>/dev/null || true
    kill $SOCAT_PID 2>/dev/null || true
    kill $JOPLIN_PID 2>/dev/null || true
    wait
    log "Shutdown complete"
    exit 0
}

# Set trap for cleanup
trap cleanup SIGTERM SIGINT

# Monitor processes and keep container alive with auto-sync
while true; do
    if ! kill -0 $JOPLIN_PID 2>/dev/null; then
        log "ERROR: Joplin server stopped!"
        break
    fi
    if ! kill -0 $SOCAT_PID 2>/dev/null; then
        log "WARNING: Socat proxy stopped, restarting..."
        socat TCP-LISTEN:41185,fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:41184 &
        SOCAT_PID=$!
    fi
    if ! kill -0 $API_PID 2>/dev/null; then
        log "ERROR: API server stopped!"
        break
    fi
    
    # Auto-sync functionality
    if [ "$SYNC_TARGET" -ne 0 ]; then
        CURRENT_TIME=$(date +%s)
        LAST_SYNC_FILE="/data/joplin/last_sync_time"
        
        # Get last sync time or set to 0
        if [ -f "$LAST_SYNC_FILE" ]; then
            LAST_SYNC_TIME=$(cat "$LAST_SYNC_FILE")
        else
            LAST_SYNC_TIME=0
        fi
        
        # Check if it's time to sync
        TIME_DIFF=$((CURRENT_TIME - LAST_SYNC_TIME))
        if [ $TIME_DIFF -ge $SYNC_INTERVAL ]; then
            log "Auto-sync triggered (interval: ${SYNC_INTERVAL}s, last sync: ${TIME_DIFF}s ago)"
            
            # Run sync as joplin user
            su joplin -c 'export HOME=/data/joplin; cd /data/joplin; joplin sync' > /tmp/auto_sync.log 2>&1 &
            SYNC_PID=$!
            
            # Update last sync time
            echo $CURRENT_TIME > "$LAST_SYNC_FILE"
            
            # Wait for sync to complete (non-blocking)
            if wait $SYNC_PID; then
                log "Auto-sync completed successfully"
            else
                log "Auto-sync failed, check logs"
            fi
        fi
    fi
    
    sleep 30
done

log "One or more services stopped. Cleaning up..."
cleanup