#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# upload_screenshots.sh  –  Upload App Store screenshots in one command
#
# ONE-TIME SETUP:
#   1. Go to https://appleid.apple.com → Sign-In and Security → App-Specific Passwords
#   2. Generate a password, copy it (looks like: xxxx-xxxx-xxxx-xxxx)
#   3. Run these two lines once in your terminal, then run this script:
#        export FASTLANE_USER="your@apple.id"
#        export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
# ─────────────────────────────────────────────────────────────────────────────

if [[ -z "$FASTLANE_USER" || -z "$FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" ]]; then
  echo ""
  echo "Two env vars needed (run once, then re-run this script):"
  echo ""
  echo "  export FASTLANE_USER=\"your@apple.id\""
  echo "  export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
  echo ""
  echo "Get an app-specific password at: https://appleid.apple.com"
  echo "  → Sign-In and Security → App-Specific Passwords"
  exit 1
fi

# Copy latest screenshots into the fastlane folder
SS_DIR="$(dirname "$0")/../fastlane/screenshots/en-US/iPhone 6.5-inch"
mkdir -p "$SS_DIR"
cp /tmp/screenshots/*.png "$SS_DIR/" 2>/dev/null || true

echo "=== Uploading screenshots to App Store Connect ==="
echo "App  : com.waelio.Welcom (Safe Talk)"
echo "Slot : iPhone 6.5-inch  •  en-US"
echo ""

cd "$(dirname "$0")/.."

fastlane deliver \
  --screenshots_path "./fastlane/screenshots" \
  --skip_metadata \
  --skip_binary_upload \
  --overwrite_screenshots \
  --force

if [[ $? -eq 0 ]]; then
  echo ""
  echo "Done! Screenshots are live on App Store Connect."
else
  echo ""
  echo "Upload failed — check output above."
  exit 1
fi
