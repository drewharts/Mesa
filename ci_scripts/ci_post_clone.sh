#!/bin/sh
# Xcode Cloud: runs after the repo is cloned, before the build.
# Needs workflow environment variables (mark both Secret): GMS_API_KEY, POSTHOG_API_KEY.
# Optional: MESA_API_BASE_URL to force a backend; otherwise branch decides.
set -eu
cd "$CI_PRIMARY_REPOSITORY_PATH"

# 1. Secrets.xcconfig (gitignored) from secret env vars. Never echo the values.
printf 'GMS_API_KEY = %s\nPOSTHOG_API_KEY = %s\n' "${GMS_API_KEY:-}" "${POSTHOG_API_KEY:-}" > Secrets.xcconfig
[ -n "${GMS_API_KEY:-}" ] || echo "warning: GMS_API_KEY not set"
[ -n "${POSTHOG_API_KEY:-}" ] || echo "warning: POSTHOG_API_KEY not set (analytics off)"

# 2. Backend: main / tags -> production (the default in the project), anything else -> staging.
#    MESA_API_BASE_URL is a target-level build setting, so patch the project file in place.
BRANCH="${CI_BRANCH:-}"
if [ -n "${MESA_API_BASE_URL:-}" ]; then
  URL="$MESA_API_BASE_URL"
elif [ "$BRANCH" = "main" ] || [ -n "${CI_TAG:-}" ]; then
  URL="https://mesa.drewharts.com"
else
  URL="https://mesa-backend-staging.up.railway.app"
fi
sed -i '' "s#MESA_API_BASE_URL = \"[^\"]*\";#MESA_API_BASE_URL = \"$URL\";#g" loc.xcodeproj/project.pbxproj
echo "branch=${BRANCH:-?} backend=$URL build=${CI_BUILD_NUMBER:-?}"

# Build number: Xcode Cloud stamps CI_BUILD_NUMBER itself. Set "Next Build Number"
# above the last uploaded build (2003) once in App Store Connect > Xcode Cloud > Settings.
