#!/usr/bin/env python3
"""
HA Joplin Bridge Management API for Home Assistant Add-on
"""

from flask import Flask, jsonify, request
import subprocess  # nosec B404 - needed for Joplin CLI commands
import os
import threading
from datetime import datetime

app = Flask(__name__)

# Global variable for sync tracking
sync_status = {"running": False, "last_sync": None, "error": None, "output": None}


def run_joplin_command(command, args=None, timeout=120):
    """Execute Joplin CLI command"""
    try:
        # Build command with safe input validation
        if not isinstance(command, str) or not command.isalnum():
            raise ValueError("Invalid command format")

        cmd = ["joplin", command]
        if args:
            if isinstance(args, list):
                # Validate each argument
                for arg in args:
                    if not isinstance(arg, str):
                        raise ValueError("Invalid argument type")
                cmd.extend(args)
            else:
                if not isinstance(args, str):
                    raise ValueError("Invalid argument type")
                cmd.append(str(args))

        env = os.environ.copy()
        env["HOME"] = "/data/joplin"
        env["JOPLIN_PROFILE"] = "/data/joplin/.config/joplin"

        # Safe subprocess call with controlled input
        result = subprocess.run(  # nosec B603 - controlled input validation above
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd="/data/joplin",
            env=env,
            shell=False,  # Explicitly disable shell
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


def background_sync():
    """Background synchronization"""
    global sync_status
    try:
        sync_status["running"] = True
        sync_status["error"] = None
        sync_status["output"] = None

        result = run_joplin_command("sync", timeout=300)

        sync_status["running"] = False
        sync_status["last_sync"] = datetime.now().isoformat()
        sync_status["output"] = result["stdout"]

        if not result["success"]:
            sync_status["error"] = result["stderr"] or result["stdout"]

    except Exception as e:
        sync_status["running"] = False
        sync_status["error"] = str(e)


@app.route("/health", methods=["GET"])
def health_check():
    """Health check for API"""
    return jsonify(
        {
            "status": "healthy",
            "joplin_api_available": True,
            "sync_running": sync_status["running"],
            "addon_version": "1.0.0",
        }
    )


@app.route("/token", methods=["GET"])
def get_token():
    """Get Joplin API token"""
    result = run_joplin_command("config", ["api.token"])

    if result["success"]:
        token_line = result["stdout"]
        if "=" in token_line:
            token = token_line.split("=")[1].strip()
            return jsonify(
                {
                    "success": True,
                    "token": token,
                    "joplin_data_api_url": f'http://{request.host.split(":")[0]}:41185',
                }
            )
        else:
            return jsonify({"success": False, "error": "Could not parse token"}), 500
    else:
        return (
            jsonify(
                {"success": False, "error": result["stderr"] or "Failed to get token"}
            ),
            500,
        )


@app.route("/sync", methods=["POST"])
def sync_notes():
    """Start note synchronization"""
    global sync_status

    data = request.get_json() if request.is_json else {}
    background = data.get("background", True)

    if sync_status["running"]:
        return (
            jsonify(
                {
                    "success": False,
                    "message": "Sync already in progress",
                    "status": sync_status,
                }
            ),
            409,
        )

    if background:
        sync_thread = threading.Thread(target=background_sync)
        sync_thread.daemon = True
        sync_thread.start()

        return jsonify(
            {
                "success": True,
                "message": "Background sync started",
                "status": sync_status,
            }
        )
    else:
        result = run_joplin_command("sync", timeout=300)
        sync_status["last_sync"] = datetime.now().isoformat()
        sync_status["output"] = result["stdout"]

        if not result["success"]:
            sync_status["error"] = result["stderr"]

        return jsonify(
            {
                "success": result["success"],
                "message": "Sync completed",
                "output": result["stdout"],
                "error": result["stderr"] if not result["success"] else None,
                "status": sync_status,
            }
        )


@app.route("/sync/status", methods=["GET"])
def sync_status_endpoint():
    """Get synchronization status"""
    return jsonify({"success": True, "status": sync_status})


@app.route("/info", methods=["GET"])
def get_info():
    """Get Joplin information"""
    status_result = run_joplin_command("status")
    config_result = run_joplin_command("config", ["sync.target"])

    sync_target = "Unknown"
    if config_result["success"] and "=" in config_result["stdout"]:
        sync_target = config_result["stdout"].split("=")[1].strip()

    return jsonify(
        {
            "success": True,
            "addon_version": "1.0.0",
            "joplin_version": "CLI",
            "status": (
                status_result["stdout"] if status_result["success"] else "Unknown"
            ),
            "sync_target": sync_target,
            "sync_status": sync_status,
            "api_endpoints": {
                "token": "/token",
                "health": "/health",
                "info": "/info",
                "sync": "/sync (POST)",
                "sync_status": "/sync/status",
            },
            "joplin_data_api_url": f'http://{request.host.split(":")[0]}:41185',
        }
    )


if __name__ == "__main__":
    # Bind to localhost only for security - container networking handles external access
    app.run(
        host="127.0.0.1", port=41186, debug=False
    )  # nosec B104 - controlled environment