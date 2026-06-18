#!/usr/bin/env python3
"""
One-click build, install, and debug for iPad Mini 1.

Usage:
    python3 deploy.py           # Build + sign + try install (fallback: IPA ready for Sideloadly)
    python3 deploy.py --build   # Build only (rebuild .ipa in build_output/)
    python3 deploy.py --install # Build + sign + try install on device
    python3 deploy.py --logs    # Tail real-time NSLog from connected device
"""
import os
import re
import sys
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BUILD_DIR = os.path.join(SCRIPT_DIR, "build_output")
APP_BUNDLE = os.path.join(BUILD_DIR, "ChineseApp.app")
BINARY = os.path.join(APP_BUNDLE, "ChineseApp")
COMPILE_SCRIPT = os.path.join(SCRIPT_DIR, "compile.py")

os.environ["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"

DEVICE_ID = None
CERT_NAME = None


def detect_cert():
    global CERT_NAME
    result = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        capture_output=True, text=True, timeout=10
    )
    for line in result.stdout.split("\n"):
        m = re.search(r'"([^"]+)"', line)
        if m and "Apple Development" in m.group(1):
            CERT_NAME = m.group(1)
            return


def find_device():
    for cmd, pattern in [
        (["ios-deploy", "--detect", "-W"], r'\(([a-f0-9]+)\)'),
        (["idevice_id", "-l"], r'([a-f0-9]+)')
    ]:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            m = re.search(pattern, result.stdout.strip())
            if m:
                return m.group(1)
        except Exception:
            continue
    return None


def build():
    print("=" * 60)
    print("  Step 1: Compiling with Xcode 13 toolchain...")
    print("=" * 60)
    result = subprocess.run([sys.executable, COMPILE_SCRIPT], cwd=SCRIPT_DIR, timeout=300)
    if result.returncode != 0:
        print("ERROR: Build failed!")
        sys.exit(1)
    print(f"  IPA ready: {os.path.join(BUILD_DIR, 'ChineseApp.ipa')}\n")


def sign():
    detect_cert()
    if not CERT_NAME:
        print("  (No Apple Development cert found, skipping codesign)")
        return

    print("=" * 60)
    print("  Code-signing binary...")
    print("=" * 60)
    result = subprocess.run(
        ["codesign", "-f", "-s", CERT_NAME, BINARY],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode == 0:
        print("  OK\n")
    else:
        print(f"  WARNING: {result.stderr.strip()}\n")


def attempt_install(just_launch):
    global DEVICE_ID
    DEVICE_ID = find_device()
    if not DEVICE_ID:
        print("  No device detected. IPA is ready for manual install via Sideloadly.")
        return False

    print(f"  Device: {DEVICE_ID}")
    print()

    cmd = [
        "ios-deploy",
        "--id", DEVICE_ID,
        "--bundle", APP_BUNDLE,
    ]
    if just_launch:
        cmd.append("--justlaunch")

    try:
        result = subprocess.run(cmd, cwd=SCRIPT_DIR, timeout=300)
        if result.returncode == 0:
            return True
        else:
            print("  (Install failed, but IPA is ready for Sideloadly)")
            return False
    except Exception as e:
        print(f"  (Install error: {e})")
        return False


def tail_logs():
    """Stream device syslog using idevicesyslog (libimobiledevice)."""
    device = find_device()
    if not device:
        print("  No device found.")
        sys.exit(1)

    print(f"  Streaming NSLog from device (Ctrl+C to stop)...\n")
    try:
        subprocess.run(["idevicesyslog", "--syslog-relay"])
    except KeyboardInterrupt:
        print("\nDone.")
    except FileNotFoundError:
        print("ERROR: 'idevicesyslog' not found. Install via: brew install libimobiledevice")


if __name__ == "__main__":
    print("🍎 Kids Chinese Learning App - Deploy Tool")
    print()

    if "--logs" in sys.argv:
        tail_logs()
    elif "--build" in sys.argv:
        build()
    elif "--install" in sys.argv:
        build()
        sign()
        attempt_install(just_launch=False)
    else:
        # Default: build + sign + try install + show logs
        build()
        sign()
        install_ok = attempt_install(just_launch=True)
        if install_ok:
            print("\nApp installed! Streaming logs...")
            tail_logs()
        else:
            print("\nTip: Use Sideloadly to install build_output/ChineseApp.ipa")
            print("  Then run: python3 deploy.py --logs")
