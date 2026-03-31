#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# upload_screenshots.sh  –  Upload App Store screenshots in one command
#
# SETUP (one-time):
#   1. In App Store Connect → Users and Access → Integrations → App Store Connect API
#      create a key with "App Manager" role.
#   2. Download the .p8 file and note the Key ID and Issuer ID.
#   3. Fill in the three variables below (or export them as env vars).
# ─────────────────────────────────────────────────────────────────────────────

APP_STORE_CONNECT_API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-}"
APP_STORE_CONNECT_API_KEY_ISSUER_ID="${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-}"
APP_STORE_CONNECT_API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"   # path to .p8 file

if [[ -z "$APP_STORE_CONNECT_API_KEY_ID" || -z "$APP_STORE_CONNECT_API_KEY_ISSUER_ID" || -z "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
  echo ""
  echo "ERROR: App Store Connect API key not configured."
  echo ""
  echo "Set these three environment variables (or edit this script):"
  echo "  export APP_STORE_CONNECT_API_KEY_ID=XXXXXXXXXX"
  echo "  export APP_STORE_CONNECT_API_KEY_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  echo "  export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8"
  echo ""
  echo "Get them at: https://appstoreconnect.apple.com/access/integrations/api"
  exit 1
fi

cd "$(dirname "$0")"

# Write a temporary api_key JSON that fastlane deliver consumes
API_KEY_JSON=$(mktemp /tmp/asc_api_key.XXXXXX.json)
cat > "$API_KEY_JSON" <<JSON
{
  "key_id":        "$APP_STORE_CONNECT_API_KEY_ID",
  "issuer_id":     "$APP_STORE_CONNECT_API_KEY_ISSUER_ID",
  "key_filepath":  "$APP_STORE_CONNECT_API_KEY_PATH",
  "in_house":      false
}
JSON

echo "=== Uploading screenshots to App Store Connect ==="
echo "App  : com.waelio.Welcom (Safe Talk)"
echo "Slot : iPhone 6.9-inch  •  Language: en-US"
echo ""

fastlane upload_screenshots api_key_path:"$API_KEY_JSON"

STATUS=$?
rm -f "$API_KEY_JSON"

if [[ $STATUS -eq 0 ]]; then
  echo ""
  echo "Done! Check App Store Connect to confirm screenshots are live."
else
  echo ""
  echo "Upload failed. Check fastlane output above for details."
  exit $STATUS
fi
