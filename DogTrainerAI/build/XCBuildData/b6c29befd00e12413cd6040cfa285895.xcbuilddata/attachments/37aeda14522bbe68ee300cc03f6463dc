#!/bin/sh
#!/bin/bash
set -euo pipefail

ENV_FILE="${SRCROOT}/.env"
PLIST="${SRCROOT}/DogTrainerAI/Resources/Secrets.plist"

if [ ! -f "$ENV_FILE" ]; then
  echo "warning: .env not found at $ENV_FILE — copy .env.example to .env and add your OpenAI key. AI features will not work until you do."
  exit 0
fi

OPENAI_KEY=""
AI_PROXY=""

while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  case "$key" in
    OPENAI_API_KEY)    OPENAI_KEY="$value" ;;
    AI_PROXY_BASE_URL) AI_PROXY="$value"   ;;
  esac
done < "$ENV_FILE"

cat > "$PLIST" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>OPENAI_API_KEY</key>
    <string>${OPENAI_KEY}</string>
    <key>AI_PROXY_BASE_URL</key>
    <string>${AI_PROXY}</string>
</dict>
</plist>
PLISTEOF

echo "✅ Secrets.plist updated from .env"

