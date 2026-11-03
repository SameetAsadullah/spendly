#!/bin/bash
# Builds origin/main from a separate clean checkout and installs it over the app on the iPhone.
# Usage: install-on-iphone.sh <device-id> [min-days]
# With min-days, it skips when the last successful install is newer than that.
# The launchd agent runs a copy in ~/Library/Application Support/Spendly, because launchd jobs
# cannot read ~/Documents without a privacy prompt. Run scripts/setup-auto-reinstall.sh after a change.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

DEVICE="${1:?usage: install-on-iphone.sh <device-id> [min-days]}"
MIN_DAYS="${2:-0}"
REPO_URL="https://github.com/SameetAsadullah/spendly.git"
BASE="$HOME/Library/Application Support/Spendly"
CHECKOUT="$BASE/checkout"
DERIVED="$BASE/DerivedData"
STAMP="$BASE/last-install"

log() { echo "$(date '+%F %T') $1"; }
notify() { osascript -e "display notification \"$1\" with title \"Spendly reinstall\"" >/dev/null 2>&1 || true; }
fail() { log "FAILED: $1"; notify "Failed: $1"; exit 1; }

if [[ -f "$STAMP" ]] && (( MIN_DAYS > 0 )); then
    age_days=$(( ($(date +%s) - $(stat -f %m "$STAMP")) / 86400 ))
    if (( age_days < MIN_DAYS )); then
        log "last install $age_days days ago, skipped"
        exit 0
    fi
fi

log "start"
mkdir -p "$BASE"
[[ -d "$CHECKOUT/.git" ]] || git clone -q "$REPO_URL" "$CHECKOUT" || fail "git clone"
git -C "$CHECKOUT" fetch -q origin main || fail "git fetch"
git -C "$CHECKOUT" reset -q --hard origin/main
git -C "$CHECKOUT" clean -qfdx
commit=$(git -C "$CHECKOUT" rev-parse --short HEAD)

(cd "$CHECKOUT" && xcodegen generate --quiet) || fail "xcodegen"
xcodebuild -project "$CHECKOUT/Spendly.xcodeproj" -scheme Spendly -configuration Debug \
    -destination "id=$DEVICE" -derivedDataPath "$DERIVED" -allowProvisioningUpdates -quiet build \
    || fail "build of $commit"
xcrun devicectl device install app --device "$DEVICE" "$DERIVED/Build/Products/Debug-iphoneos/Spendly.app" \
    || fail "install. Is the iPhone on the same Wi-Fi and unlocked?"

touch "$STAMP"
log "installed $commit"
notify "Installed $commit. It runs for 7 more days."
