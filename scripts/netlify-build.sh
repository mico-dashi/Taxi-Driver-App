#!/usr/bin/env bash
# Builds the website on Netlify (free plan): the live app at / and the
# offline demo at /demo/. Netlify runs this on every push to main.
set -euo pipefail

FLUTTER_VERSION=3.47.5
FLUTTER_DIR="$HOME/flutter-$FLUTTER_VERSION"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter --version

cd "$(dirname "$0")/../app"
flutter pub get
rm -rf ../site
flutter build web --release --dart-define-from-file=config/live.json --output=../site
flutter build web --release --base-href /demo/ --output=../site/demo
