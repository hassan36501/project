#!/usr/bin/env bash
# Repeatable process-crash test for the file-backed Legder store.
#
# NOTE ON GUARANTEES:
# Killing a process with SIGKILL is NOT identical to physical power loss.
# The OS kernel page cache survives SIGKILL, whereas a real power cut
# loses un-flushed disk controller / OS caches. Here, Sync calls fsync()
# so committed records are durable on disk; SIGKILL mid-loop tests that
# reopening the file recovers a clean, consistent prefix without corruption.

set -euo pipefail

cd "$(dirname "$0")"

DATA_FILE="crash_test.dat"
rm -f "$DATA_FILE"

echo "=== Building file device demo and crash writer ==="
alr -n build

echo "=== Starting crash_writer in background ==="
./bin/crash_writer "$DATA_FILE" &
WRITER_PID=$!

# Let it commit some records, then interrupt with SIGKILL
sleep 0.2
if kill -0 "$WRITER_PID" 2>/dev/null; then
   echo "=== Sending SIGKILL to pid $WRITER_PID ==="
   kill -9 "$WRITER_PID"
   wait "$WRITER_PID" 2>/dev/null || true
else
   echo "=== Writer already finished ==="
   wait "$WRITER_PID"
fi

echo "=== Verifying recovery with file_demo ==="
./bin/file_demo

rm -f "$DATA_FILE"
echo "=== Crash test passed ==="
