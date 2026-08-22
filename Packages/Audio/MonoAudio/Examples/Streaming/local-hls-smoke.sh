#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/mono-audio-hls.XXXXXX")"
PORT="${MONO_AUDIO_SMOKE_PORT:-18765}"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

mkdir -p "$WORK/hls"
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i "sine=frequency=440:sample_rate=48000" \
  -t 4 -c:a aac -b:a 96k \
  -hls_time 1 -hls_list_size 0 \
  "$WORK/hls/index.m3u8"

cat > "$WORK/server.py" <<'PY'
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
import sys

root, port = sys.argv[1], int(sys.argv[2])
os.chdir(root)

class Handler(SimpleHTTPRequestHandler):
    def do_POST(self):
        output = os.path.join(root, "relayed.ts")
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            with open(output, "wb") as sink:
                while True:
                    size = int(self.rfile.readline().split(b";", 1)[0], 16)
                    if size == 0:
                        self.rfile.readline()
                        break
                    sink.write(self.rfile.read(size))
                    self.rfile.read(2)
        else:
            size = int(self.headers.get("Content-Length", "0"))
            with open(output, "wb") as sink:
                sink.write(self.rfile.read(size))
        self.send_response(200)
        self.end_headers()

    def log_message(self, *_):
        pass

ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY

/usr/bin/python3 "$WORK/server.py" "$WORK/hls" "$PORT" &
SERVER_PID=$!
for _ in {1..50}; do
  if curl --silent --fail "http://127.0.0.1:$PORT/index.m3u8" >/dev/null; then
    break
  fi
  sleep 0.1
done
curl --silent --fail "http://127.0.0.1:$PORT/index.m3u8" >/dev/null

PLAN_JSON="$(cat "$ROOT/Examples/neutral-plan.json")"
cat > "$WORK/relay.json" <<JSON
{
  "source": {
    "id": "local-hls-smoke",
    "endpoint": {
      "url": "http://127.0.0.1:$PORT/index.m3u8",
      "streamProtocol": "hls",
      "format": "hls"
    },
    "request": {
      "headers": {},
      "connectionTimeoutMilliseconds": 2000,
      "readTimeoutMilliseconds": 5000,
      "reconnect": {
        "isEnabled": true,
        "reconnectAtEndOfFile": false,
        "reconnectOnNetworkError": true,
        "maximumDelaySeconds": 1
      },
      "rtspTransport": "automatic"
    }
  },
  "destination": {
    "url": "http://127.0.0.1:$PORT/relayed.ts",
    "streamProtocol": "http",
    "format": "mpegTS"
  },
  "tuningPlan": $PLAN_JSON,
  "audioCodec": "aac",
  "audioBitrateKilobitsPerSecond": 96,
  "maximumDurationSeconds": 2
}
JSON

cd "$ROOT"
swift run mono-audio relay "$WORK/relay.json" --check-capabilities > "$WORK/result.json"
grep -q '"-af"' "$WORK/result.json"
grep -q 'alimiter=' "$WORK/result.json"
test -s "$WORK/hls/relayed.ts"
CODEC_NAME="$(
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
    -of csv=p=0 "$WORK/hls/relayed.ts" | sed '/^$/d' | sort -u
)"
if [[ "$CODEC_NAME" != "aac" ]]; then
  echo "unexpected relay codec: $CODEC_NAME" >&2
  exit 1
fi
echo "codec_name=$CODEC_NAME"
shasum -a 256 "$WORK/hls/relayed.ts"
echo "local HLS relay smoke test passed"
