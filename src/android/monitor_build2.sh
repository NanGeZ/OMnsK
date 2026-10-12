#!/usr/bin/env bash
set -uo pipefail
export JAVA_HOME=/root/.local/share/mise/installs/java/17
export ANDROID_HOME=/root/Android/sdk
export ANDROID_NDK_HOME=/root/Android/sdk/ndk/27.0.12077973
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
cd /workspace/src/android
LOG=/workspace/src/android/build_release.log
PSLOG=/workspace/src/android/psmon2.log
JLOG=/workspace/src/android/jcmdmon.log
: > "$LOG"; : > "$PSLOG"; : > "$JLOG"

./gradlew --no-daemon :app:assembleRelease > "$LOG" 2>&1 &
GPID=$!

declare -A SEEN
while kill -0 "$GPID" 2>/dev/null; do
  echo "=== $(date +%T) cg=$(cat /sys/fs/cgroup/memory.current 2>/dev/null)" >> "$PSLOG"
  for p in /proc/[0-9]*; do
    [ -r "$p/comm" ] || continue
    [ "$(cat "$p/comm" 2>/dev/null)" = "java" ] || continue
    pid=${p#/proc/}
    rss=$(awk '/VmRSS/{print $2}' "$p/status" 2>/dev/null)
    echo "PID=$pid RSS=${rss}kB" >> "$PSLOG"
    tr '\0' ' ' < "$p/cmdline" 2>/dev/null | sed 's/^/  CMD /' >> "$PSLOG"
    echo >> "$PSLOG"
    if [ -n "${SEEN[$pid]:-}" ]; then continue; fi
    if [ "${rss:-0}" -gt 2500000 ] 2>/dev/null; then
      SEEN[$pid]=1
      {
        echo "=== jcmd $pid RSS=${rss}kB"
        "$JAVA_HOME/bin/jcmd" "$pid" VM.command_line 2>&1
        "$JAVA_HOME/bin/jcmd" "$pid" VM.flags 2>&1 | tr ' ' '\n' | grep -E "MaxHeapSize|MaxMetaspaceSize|MaxRAMPercentage"
      } >> "$JLOG"
    fi
  done
  sleep 3
done

wait "$GPID"; RC=$?
echo "[build] exit=$RC"
dmesg 2>/dev/null | grep "Killed process" | tail -2
echo "--- Xmx in captured cmdlines ---"
grep -o "\-Xmx[0-9]*[mMgG]" "$PSLOG" | sort | uniq -c
echo "--- jcmd results ---"
cat "$JLOG"
tail -8 "$LOG"
exit "$RC"
