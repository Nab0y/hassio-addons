#!/bin/bash
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting HA Joplin Bridge Multi-Tenant..."

# Arrays to track PIDs
declare -a JOPLIN_PIDS
declare -a SOCAT_PIDS

# Read configuration from options file (Home Assistant way)
if [ -f /data/options.json ]; then
    log "Reading configuration from /data/options.json"
    
    # Check if multi-user mode is configured
    USERS_COUNT=$(jq '.users | length' /data/options.json)
    
    if [ "$USERS_COUNT" -gt 0 ]; then
        log "Multi-user mode detected: $USERS_COUNT users"
        MODE="multi"
    else
        log "Single-user mode (legacy)"
        MODE="single"
        # Read legacy configuration
        SYNC_TARGET=$(jq -r '.sync_target // 0' /data/options.json)
        SYNC_INTERVAL=$(jq -r '.sync_interval // 300' /data/options.json)
        LOCALE=$(jq -r '.locale // "en_GB"' /data/options.json)
        TIMEZONE=$(jq -r '.timezone // "UTC"' /data/options.json)
        ENABLE_ENCRYPTION=$(jq -r '.enable_encryption // false' /data/options.json)
        ENCRYPTION_PASSWORD=$(jq -r '.encryption_password // ""' /data/options.json)
        SYNC_SERVER_URL=$(jq -r '.sync_server_url // ""' /data/options.json)
        SYNC_USERNAME=$(jq -r '.sync_username // ""' /data/options.json)
        SYNC_PASSWORD=$(jq -r '.sync_password // ""' /data/options.json)
    fi
else
    log "No options.json found, using defaults"
    MODE="single"
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

# Set timezone
if [ "$MODE" = "multi" ]; then
    # Use first user's timezone or default
    TIMEZONE=$(jq -r '.users[0].timezone // "UTC"' /data/options.json)
fi
export TZ=$TIMEZONE
if [ -f /usr/share/zoneinfo/$TZ ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
    log "Timezone set to $TZ"
fi

# Create base directories
mkdir -p /data/joplin
chown -R joplin:joplin /data/joplin 2>/dev/null || true

# Function to configure single Joplin instance
configure_joplin_profile() {
    local PROFILE_NAME=$1
    local PROFILE_DIR=$2
    local PORT=$3
    local USER_SYNC_TARGET=$4
    local USER_SYNC_INTERVAL=$5
    local USER_LOCALE=$6
    local USER_SYNC_URL=$7
    local USER_SYNC_USERNAME=$8
    local USER_SYNC_PASSWORD=$9
    
    log "Configuring Joplin profile: $PROFILE_NAME on port $PORT"
    
    # Create profile directory
    mkdir -p "$PROFILE_DIR"
    chown -R joplin:joplin "$PROFILE_DIR" 2>/dev/null || true
    
    # Configure Joplin as joplin user
    su joplin -c '
export HOME='"$PROFILE_DIR"'
export JOPLIN_PROFILE='"$PROFILE_DIR"'/.config/joplin
cd '"$PROFILE_DIR"'

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Configuring '"$PROFILE_NAME"'..."

# Create basic Joplin config
joplin config locale "'"$USER_LOCALE"'" 2>/dev/null || true
joplin config sync.target '"$USER_SYNC_TARGET"' 2>/dev/null || true
joplin config sync.interval '"$USER_SYNC_INTERVAL"' 2>/dev/null || true

# Configure sync if needed
if [ '"$USER_SYNC_TARGET"' -ne 0 ] && [ "'"$USER_SYNC_URL"'" != "null" ] && [ -n "'"$USER_SYNC_URL"'" ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Setting up sync for '"$PROFILE_NAME"' (target '"$USER_SYNC_TARGET"')..."
    if [ '"$USER_SYNC_TARGET"' -eq 9 ]; then
        joplin config sync.9.path "'"$USER_SYNC_URL"'" 2>/dev/null || true
        [ "'"$USER_SYNC_USERNAME"'" != "null" ] && [ -n "'"$USER_SYNC_USERNAME"'" ] && joplin config sync.9.username "'"$USER_SYNC_USERNAME"'" 2>/dev/null || true
        [ "'"$USER_SYNC_PASSWORD"'" != "null" ] && [ -n "'"$USER_SYNC_PASSWORD"'" ] && joplin config sync.9.password "'"$USER_SYNC_PASSWORD"'" 2>/dev/null || true
    elif [ '"$USER_SYNC_TARGET"' -eq 5 ]; then
        joplin config sync.5.path "'"$USER_SYNC_URL"'" 2>/dev/null || true
        [ "'"$USER_SYNC_USERNAME"'" != "null" ] && [ -n "'"$USER_SYNC_USERNAME"'" ] && joplin config sync.5.username "'"$USER_SYNC_USERNAME"'" 2>/dev/null || true
        [ "'"$USER_SYNC_PASSWORD"'" != "null" ] && [ -n "'"$USER_SYNC_PASSWORD"'" ] && joplin config sync.5.password "'"$USER_SYNC_PASSWORD"'" 2>/dev/null || true
    elif [ '"$USER_SYNC_TARGET"' -eq 8 ]; then
        joplin config sync.8.path "'"$USER_SYNC_URL"'" 2>/dev/null || true
        [ "'"$USER_SYNC_USERNAME"'" != "null" ] && [ -n "'"$USER_SYNC_USERNAME"'" ] && joplin config sync.8.accessKeyId "'"$USER_SYNC_USERNAME"'" 2>/dev/null || true
        [ "'"$USER_SYNC_PASSWORD"'" != "null" ] && [ -n "'"$USER_SYNC_PASSWORD"'" ] && joplin config sync.8.secretAccessKey "'"$USER_SYNC_PASSWORD"'" 2>/dev/null || true
    fi
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Sync configuration completed for '"$PROFILE_NAME"'"
fi
'
}

# Function to start Joplin server
start_joplin_server() {
    local PROFILE_NAME=$1
    local PROFILE_DIR=$2
    local PORT=$3
    
    log "Starting Joplin server for $PROFILE_NAME on localhost:$PORT..."
    su joplin -c "export HOME=$PROFILE_DIR; export JOPLIN_PROFILE=$PROFILE_DIR/.config/joplin; cd $PROFILE_DIR; joplin server start --port $PORT --host 127.0.0.1" &
    local PID=$!
    JOPLIN_PIDS+=($PID)
    log "$PROFILE_NAME Joplin PID: $PID"
    
    return $PID
}

# Start services based on mode
if [ "$MODE" = "single" ]; then
    log "Starting in single-user mode (legacy)"
    
    # Configure single profile
    configure_joplin_profile "default" "/data/joplin" 41184 "$SYNC_TARGET" "$SYNC_INTERVAL" "$LOCALE" "$SYNC_SERVER_URL" "$SYNC_USERNAME" "$SYNC_PASSWORD"
    
    # Start single Joplin instance
    start_joplin_server "default" "/data/joplin" 41184
    
    sleep 10
    
    # Start socat proxy
    log "Starting socat proxy for single-user mode..."
    socat TCP-LISTEN:41185,fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:41184 &
    SOCAT_PIDS+=($!)
    
else
    log "Starting in multi-user mode with $USERS_COUNT users"
    
    # Start Joplin instances for each user
    BASE_PORT=41184
    
    for ((i=0; i<$USERS_COUNT; i++)); do
        USER_NAME=$(jq -r ".users[$i].name" /data/options.json)
        PROFILE_DIR="/data/joplin/profiles/$USER_NAME"
        PORT=$((BASE_PORT + i))
        
        USER_SYNC_TARGET=$(jq -r ".users[$i].sync_target // 0" /data/options.json)
        USER_SYNC_INTERVAL=$(jq -r ".users[$i].sync_interval // 300" /data/options.json)
        USER_LOCALE=$(jq -r ".users[$i].locale // \"en_GB\"" /data/options.json)
        USER_SYNC_URL=$(jq -r ".users[$i].sync_server_url // \"\"" /data/options.json)
        USER_SYNC_USERNAME=$(jq -r ".users[$i].sync_username // \"\"" /data/options.json)
        USER_SYNC_PASSWORD=$(jq -r ".users[$i].sync_password // \"\"" /data/options.json)
        
        log "Setting up user $((i+1))/$USERS_COUNT: $USER_NAME"
        
        # Configure profile
        configure_joplin_profile "$USER_NAME" "$PROFILE_DIR" "$PORT" "$USER_SYNC_TARGET" "$USER_SYNC_INTERVAL" "$USER_LOCALE" "$USER_SYNC_URL" "$USER_SYNC_USERNAME" "$USER_SYNC_PASSWORD"
        
        # Start Joplin server
        start_joplin_server "$USER_NAME" "$PROFILE_DIR" "$PORT"
        
        sleep 3
    done
    
    log "All Joplin instances started, waiting for initialization..."
    sleep 10
fi

# Start API servers
log "Starting Management API server on port 41186..."
python3 /api_server.py &
MGMT_API_PID=$!
log "Management API PID: $MGMT_API_PID"

if [ "$MODE" = "multi" ]; then
    log "Starting Joplin Data API Proxy on port 41185..."
    python3 /api_server.py --data-api &
    DATA_API_PID=$!
    log "Data API Proxy PID: $DATA_API_PID"
else
    log "Single-user mode: using socat proxy on port 41185"
    DATA_API_PID="N/A"
fi

log "All services started successfully"
log "Mode: $MODE"
if [ "$MODE" = "single" ]; then
    log "Joplin PIDs: ${JOPLIN_PIDS[*]}"
    log "Socat PIDs: ${SOCAT_PIDS[*]}"
else
    log "Joplin PIDs: ${JOPLIN_PIDS[*]}"
    log "Multi-tenant proxy active on port 41185"
fi
log "Management API PID: $MGMT_API_PID"
log "Data API Proxy PID: $DATA_API_PID"

# Cleanup function
cleanup() {
    log "Shutting down services..."
    kill "$MGMT_API_PID" 2>/dev/null || true
    if [ "$DATA_API_PID" != "N/A" ]; then
        kill "$DATA_API_PID" 2>/dev/null || true
    fi
    for pid in "${SOCAT_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    for pid in "${JOPLIN_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait
    log "Shutdown complete"
    exit 0
}

# Set trap for cleanup
trap cleanup SIGTERM SIGINT

# Monitor processes and keep container alive
while true; do
    # Check if API servers are running
    if ! kill -0 "$MGMT_API_PID" 2>/dev/null; then
        log "ERROR: Management API server stopped!"
        break
    fi
    
    if [ "$MODE" = "multi" ] && [ "$DATA_API_PID" != "N/A" ]; then
        if ! kill -0 "$DATA_API_PID" 2>/dev/null; then
            log "ERROR: Data API Proxy stopped!"
            break
        fi
    fi
    
    # Check Joplin processes
    for i in "${!JOPLIN_PIDS[@]}"; do
        pid="${JOPLIN_PIDS[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            log "WARNING: Joplin instance $i stopped!"
            # Could add restart logic here
        fi
    done
    
    # Check socat processes (single mode only)
    if [ "$MODE" = "single" ]; then
        for i in "${!SOCAT_PIDS[@]}"; do
            pid="${SOCAT_PIDS[$i]}"
            if ! kill -0 "$pid" 2>/dev/null; then
                log "WARNING: Socat proxy stopped, restarting..."
                socat TCP-LISTEN:41185,fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:41184 &
                SOCAT_PIDS[$i]=$!
            fi
        done
    fi
    
    # Auto-sync functionality (if needed, can be implemented per-profile)
    
    sleep 30
done

log "One or more services stopped. Cleaning up..."
cleanup
