#!/usr/bin/env python3
"""
HA Joplin Bridge Management API for Home Assistant Add-on
Multi-Tenant Edition with Smart Token Routing
"""

from flask import Flask, jsonify, request, Response
import subprocess  # nosec B404 - needed for Joplin CLI commands
import os
import json
import threading
import requests
from datetime import datetime
from typing import Dict, Optional

app = Flask(__name__)

# Global configuration
config = {
    "mode": "single",  # "single" or "multi"
    "users": [],  # List of user configurations
    "token_map": {},  # Maps token -> user profile
    "version": "2.0.2",
}

# Global variable for sync tracking per user
sync_status = {}  # profile_name -> {running, last_sync, error, output}


def load_configuration():
    """Load configuration from /data/options.json"""
    try:
        with open("/data/options.json", "r") as f:
            options = json.load(f)

        users = options.get("users", [])

        if len(users) == 0:
            app.logger.error("No users configured! Please add users array to configuration.")
            return False

        config["mode"] = "multi"
        config["users"] = users
        app.logger.info(f"Multi-tenant mode: {len(users)} users configured")

        # Initialize sync status for each user
        for user in config["users"]:
            profile_name = user["name"]
            sync_status[profile_name] = {
                "running": False,
                "last_sync": None,
                "error": None,
                "output": None,
            }

        return True
    except Exception as e:
        app.logger.error(f"Failed to load configuration: {e}")
        return False


def get_profile_dir(profile_name: str) -> str:
    """Get profile directory path"""
    return f"/data/joplin/profiles/{profile_name}"


def get_profile_port(profile_name: str) -> int:
    """Get Joplin server port for a profile"""
    # Find user index and calculate port
    for idx, user in enumerate(config["users"]):
        if user["name"] == profile_name:
            return 41184 + idx

    raise ValueError(f"Profile {profile_name} not found")


def run_joplin_command(profile_name: str, command: str, args=None, timeout=120) -> Dict:
    """Execute Joplin CLI command for specific profile"""
    try:
        if not isinstance(command, str) or not command.replace("_", "").isalnum():
            raise ValueError("Invalid command format")

        cmd = ["joplin", command]
        if args:
            if isinstance(args, list):
                for arg in args:
                    if not isinstance(arg, str):
                        raise ValueError("Invalid argument type")
                cmd.extend(args)
            else:
                if not isinstance(args, str):
                    raise ValueError("Invalid argument type")
                cmd.append(str(args))

        profile_dir = get_profile_dir(profile_name)
        env = os.environ.copy()
        env["HOME"] = profile_dir
        env["JOPLIN_PROFILE"] = f"{profile_dir}/.config/joplin"

        result = subprocess.run(  # nosec B603 - controlled input validation
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=profile_dir,
            env=env,
            shell=False,
        )

        return {
            "success": result.returncode == 0,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "returncode": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Command timed out after {timeout} seconds",
            "returncode": -1,
        }
    except (ValueError, OSError) as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Security error: {str(e)}",
            "returncode": -1,
        }
    except Exception as e:
        return {"success": False, "stdout": "", "stderr": str(e), "returncode": -1}


def get_token_for_profile(profile_name: str) -> Optional[str]:
    """Get API token for a profile"""
    result = run_joplin_command(profile_name, "config", ["api.token"])

    if result["success"]:
        token_line = result["stdout"]
        if "=" in token_line:
            token = token_line.split("=")[1].strip()
            # Cache token mapping
            config["token_map"][token] = profile_name
            return token
    return None


def get_profile_from_token(token: str) -> Optional[str]:
    """Get profile name from token"""
    # Check cache first
    if token in config["token_map"]:
        return config["token_map"][token]

    # Rebuild token map
    for user in config["users"]:
        profile_name = user["name"]
        profile_token = get_token_for_profile(profile_name)
        if profile_token == token:
            return profile_name

    return None


def proxy_to_joplin(profile_name: str, path: str, method: str, data=None) -> Response:
    """Proxy request to specific Joplin instance"""
    try:
        port = get_profile_port(profile_name)
        url = f"http://127.0.0.1:{port}{path}"

        app.logger.info(
            f"Proxying {method} {path} to profile {profile_name} on port {port}"
        )

        headers = {"Content-Type": "application/json"}

        if method == "GET":
            resp = requests.get(url, headers=headers, timeout=30)
        elif method == "POST":
            resp = requests.post(url, json=data, headers=headers, timeout=30)
        elif method == "PUT":
            resp = requests.put(url, json=data, headers=headers, timeout=30)
        elif method == "DELETE":
            resp = requests.delete(url, headers=headers, timeout=30)
        else:
            return Response("Method not allowed", status=405)

        return Response(
            resp.content, status=resp.status_code, headers=dict(resp.headers)
        )

    except requests.exceptions.RequestException as e:
        app.logger.error(f"Proxy error: {e}")
        return Response(
            json.dumps({"error": f"Failed to proxy request: {str(e)}"}),
            status=502,
            content_type="application/json",
        )


def background_sync(profile_name: str):
    """Background synchronization for specific profile"""
    try:
        sync_status[profile_name]["running"] = True
        sync_status[profile_name]["error"] = None
        sync_status[profile_name]["output"] = None

        result = run_joplin_command(profile_name, "sync", timeout=300)

        sync_status[profile_name]["running"] = False
        sync_status[profile_name]["last_sync"] = datetime.now().isoformat()
        sync_status[profile_name]["output"] = result["stdout"]

        if not result["success"]:
            sync_status[profile_name]["error"] = result["stderr"] or result["stdout"]

    except Exception as e:
        sync_status[profile_name]["running"] = False
        sync_status[profile_name]["error"] = str(e)


# ============================================================================
# Management API Endpoints (Port 41186)
# ============================================================================


@app.route("/health", methods=["GET"])
def health_check():
    """Health check for API"""
    return jsonify(
        {
            "status": "healthy",
            "mode": config["mode"],
            "users_count": len(config["users"]),
            "addon_version": config["version"],
        }
    )


@app.route("/token", methods=["GET"])
def get_token():
    """Get Joplin API token(s) for all users"""
    tokens = {}
    for user in config["users"]:
        profile_name = user["name"]
        token = get_token_for_profile(profile_name)
        if token:
            tokens[profile_name] = {
                "token": token,
                "joplin_data_api_url": f'http://{request.host.split(":")[0]}:41185',
            }

    return jsonify(
        {
            "success": True,
            "mode": "multi-tenant",
            "users": tokens,
        }
    )


@app.route("/sync", methods=["POST"])
def sync_notes():
    """Start note synchronization"""
    data = request.get_json() if request.is_json else {}
    background = data.get("background", True)
    profile_name = data.get("profile", None)

    if not profile_name:
        return (
            jsonify(
                {
                    "success": False,
                    "error": "Profile name required",
                }
            ),
            400,
        )

    if sync_status[profile_name]["running"]:
        return (
            jsonify(
                {
                    "success": False,
                    "message": f"Sync already in progress for {profile_name}",
                    "status": sync_status[profile_name],
                }
            ),
            409,
        )

    if background:
        sync_thread = threading.Thread(target=background_sync, args=(profile_name,))
        sync_thread.daemon = True
        sync_thread.start()

        return jsonify(
            {
                "success": True,
                "message": f"Background sync started for {profile_name}",
                "status": sync_status[profile_name],
            }
        )
    else:
        result = run_joplin_command(profile_name, "sync", timeout=300)
        sync_status[profile_name]["last_sync"] = datetime.now().isoformat()
        sync_status[profile_name]["output"] = result["stdout"]

        if not result["success"]:
            sync_status[profile_name]["error"] = result["stderr"]

        return jsonify(
            {
                "success": result["success"],
                "message": f"Sync completed for {profile_name}",
                "output": result["stdout"],
                "error": result["stderr"] if not result["success"] else None,
                "status": sync_status[profile_name],
            }
        )


@app.route("/sync/status", methods=["GET"])
def sync_status_endpoint():
    """Get synchronization status"""
    profile_name = request.args.get("profile", None)

    if not profile_name:
        # Return all statuses
        return jsonify(
            {"success": True, "mode": "multi-tenant", "statuses": sync_status}
        )
    else:
        return jsonify({"success": True, "status": sync_status.get(profile_name, {})})


@app.route("/info", methods=["GET"])
def get_info():
    """Get Joplin information"""
    profile_name = request.args.get("profile", None)
    
    if not profile_name and len(config["users"]) > 0:
        profile_name = config["users"][0]["name"]

    status_result = run_joplin_command(profile_name, "status")
    config_result = run_joplin_command(profile_name, "config", ["sync.target"])

    sync_target = "Unknown"
    if config_result["success"] and "=" in config_result["stdout"]:
        sync_target = config_result["stdout"].split("=")[1].strip()

    info = {
        "success": True,
        "addon_version": config["version"],
        "mode": config["mode"],
        "joplin_version": "CLI",
        "status": status_result["stdout"] if status_result["success"] else "Unknown",
        "sync_target": sync_target,
        "sync_status": sync_status.get(profile_name, {}),
        "api_endpoints": {
            "token": "/token",
            "health": "/health",
            "info": "/info",
            "sync": "/sync (POST)",
            "sync_status": "/sync/status",
        },
        "joplin_data_api_url": f'http://{request.host.split(":")[0]}:41185',
    }

    info["users"] = [user["name"] for user in config["users"]]

    return jsonify(info)


# ============================================================================
# Joplin Data API Proxy (Port 41185)
# ============================================================================


@app.route("/<path:path>", methods=["GET", "POST", "PUT", "DELETE"])
def joplin_data_api_proxy(path):
    """
    Smart proxy for Joplin Data API with multi-tenant routing
    Routes requests based on token parameter
    """
    # Extract token from query parameters
    token = request.args.get("token")

    if not token:
        return (
            jsonify({"error": "Authentication token required"}),
            401,
        )

    # Get profile from token
    profile_name = get_profile_from_token(token)

    if not profile_name:
        return (
            jsonify({"error": "Invalid token"}),
            403,
        )

    # Build path with query parameters
    query_string = request.query_string.decode("utf-8")
    full_path = f"/{path}"
    if query_string:
        full_path += f"?{query_string}"

    # Get request data if present
    data = None
    if request.is_json:
        data = request.get_json()

    # Proxy to appropriate Joplin instance
    return proxy_to_joplin(profile_name, full_path, request.method, data)


if __name__ == "__main__":
    import socket
    from waitress import serve

    # Load configuration
    if not load_configuration():
        print("FATAL: Failed to load configuration")
        exit(1)

    # Determine which port to run on based on script argument
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--data-api":
        # Run as Joplin Data API proxy (port 41185)
        port = 41185
        print(f"Starting Joplin Data API Proxy on 0.0.0.0:{port}")
        print(f"Mode: {config['mode']}")
        print(f"Users: {len(config['users'])}")
    else:
        # Run as Management API (port 41186)
        port = 41186
        print(f"Starting Management API on 0.0.0.0:{port}")

    # Check if port is available
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.bind(("0.0.0.0", port))  # nosec B104 - container networking
        sock.close()
        print(f"Port {port} is available")
    except OSError as e:
        print(f"Port {port} is not available: {e}")

    host = "0.0.0.0"  # nosec B104 - controlled environment
    serve(app, host=host, port=port, threads=4)
