#!/usr/bin/env bash
set -uo pipefail
export JAVA_HOME=/root/.local/share/mise/installs/java/17
export ANDROID_HOME=/root/Android/sdk
export ANDROID_NDK_HOME=/root/Android/sdk/ndk/27.0.12077973
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
cd /workspace/src/android
LOG=/workspace/src/android/build_release.log
PSLOG=/workspace/src/android/psmon.log
CGLOG=/workspace/src/android/cgmon.log
: > "$LOG"; : > "$PSLOG"; : > "$CGLOG"

./gradlew --no-daemon :app:assembleRelease > "$LOG" 2>&1 &
GPID=$!

while kill -0 "$GPID" 2>/dev/null; do
  {
    echo "=== $(date +%T) cgroup.current=$(cat /sys/fs/cgroup/memory.current 2>/dev/null) peak=$(cat /sys/fs/cgroup/memory.peak 2>/dev/null)"
    for p in /proc/[0-9]*; do
      if [ -r "$p/comm" ] && [ "$(cat "$p/comm" 2>/dev/null)" = "java" ]; then
        pid=${p#/proc/}
        rss=$(awk '/VmRSS/{print $2}' "$p/status" 2>/dev/null)
        echo "PID=$pid RSS=${rss}kB CMD=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null | head -c 600)"
      fi
    done
  } >> "$PSLOG" 2>/dev/null
  sleep 3
done

wait "$GPID"
RC=$?
echo "[build] exit=$RC"
grep -E "oom|Killed process" /dev/null 2>/dev/null
dmesg 2>/dev/null | grep "Killed process" | tail -3
tail -15 "$LOG"
echo "--- largest RSS snapshots ---"
grep "RSS=" "$PSLOG" | awk -F'RSS=' '{split($2,a,"kB"); if(a[1]+0>1500000) print a[1], substr($0, index($0,"CMD="))}' | sort -rn | uniq | head -6
exit "$RC"
