#!/usr/bin/env bash
# [T-build] One-shot release APK builder for the Alias build.
# Runs the gradle release assemble with a bounded memory budget and
# tails the log as it goes. Invoked with blocking=true so the parent
# agent sees the tail live and the exit code when it finishes.
set -uo pipefail

export JAVA_HOME=/root/.local/share/mise/installs/java/17
export ANDROID_HOME=/root/Android/sdk
export ANDROID_NDK_HOME=/root/Android/sdk/ndk/27.0.12077973
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

cd /workspace/src/android

LOG=/workspace/src/android/build_release.log
: > "$LOG"

echo "[build] JAVA_HOME=$JAVA_HOME"
echo "[build] ANDROID_HOME=$ANDROID_HOME"
echo "[build] log -> $LOG"

./gradlew --no-daemon :app:assembleRelease > "$LOG" 2>&1 &
GPID=$!

# Tail the log in the background so the parent sees progress as it streams.
tail -F "$LOG" 2>/dev/null &
TPID=$!

# Poll for completion while keeping memory visible.
while kill -0 "$GPID" 2>/dev/null; do
  sleep 20
done

wait "$GPID"
RC=$?

kill "$TPID" 2>/dev/null
wait "$TPID" 2>/dev/null

echo ""
echo "[build] gradle exit code = $RC"
echo "[build] ---- last 40 lines ----"
tail -40 "$LOG"

if [ "$RC" -eq 0 ]; then
  APK=/workspace/src/android/app/build/outputs/apk/release/app-release.apk
  if [ -f "$APK" ]; then
    echo ""
    echo "[build] APK OK: $APK"
    ls -la "$APK"
  else
    echo "[build] gradle returned 0 but APK not at $APK"
    find /workspace/src/android/app/build/outputs -name '*.apk' -ls 2>/dev/null
  fi
fi

exit "$RC"
