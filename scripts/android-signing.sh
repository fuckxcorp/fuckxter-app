#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
: "${ANDROID_KEYSTORE_BASE64:?Set the ANDROID_KEYSTORE_BASE64 repository secret}"
: "${ANDROID_STORE_PASSWORD:?Set the ANDROID_STORE_PASSWORD repository secret}"
: "${ANDROID_KEY_ALIAS:?Set the ANDROID_KEY_ALIAS repository secret}"
: "${ANDROID_KEY_PASSWORD:?Set the ANDROID_KEY_PASSWORD repository secret}"
umask 077
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/release.jks
keytool -list -keystore android/release.jks -storepass:env ANDROID_STORE_PASSWORD -alias "$ANDROID_KEY_ALIAS" > /dev/null
python3 - <<'PY'
import os
from pathlib import Path

def escape(value):
    return ''.join('\\' + c if c in '\\ =:#!' else '\\n' if c == '\n' else '\\r' if c == '\r' else c for c in value)

values = {
    'storeFile': 'release.jks',
    'storePassword': os.environ['ANDROID_STORE_PASSWORD'],
    'keyAlias': os.environ['ANDROID_KEY_ALIAS'],
    'keyPassword': os.environ['ANDROID_KEY_PASSWORD'],
}
content = ''.join(f'{key}={escape(value)}\n' for key, value in values.items())
Path('android/key.properties').write_text(content, encoding='utf-8')
PY
