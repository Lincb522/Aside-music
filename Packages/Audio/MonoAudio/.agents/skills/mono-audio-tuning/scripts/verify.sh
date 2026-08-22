#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd -P)"
OUTPUT_DIR="${MONO_AUDIO_VERIFY_OUTPUT:-}"
RUN_HLS_SMOKE=false

usage() {
  cat <<'EOF'
Usage: verify.sh [--hls-smoke] [--output <directory>]

Runs the portable MonoAudio checks without contacting a public endpoint:
  - validates Examples/neutral-plan.json
  - compiles the plan twice and compares the FFmpeg filtergraphs
  - builds a deterministic relay argv fixture without opening its URLs
  - inspects the local FFmpeg build when ffmpeg is installed
  - optionally runs the finite loopback-only HLS relay smoke test

Environment:
  MONO_AUDIO_FFMPEG        FFmpeg executable name or path
  MONO_AUDIO_SMOKE_PORT    Loopback port used by --hls-smoke
  MONO_AUDIO_VERIFY_OUTPUT Exact evidence directory; it must not already exist
EOF
}

while (($# > 0)); do
  case "$1" in
    --hls-smoke)
      RUN_HLS_SMOKE=true
      shift
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "missing value for --output" >&2; exit 64; }
      if [[ "$2" = /* ]]; then
        OUTPUT_DIR="$2"
      else
        OUTPUT_DIR="$PROJECT_ROOT/$2"
      fi
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

PLAN="$PROJECT_ROOT/Examples/neutral-plan.json"
RELAY_FIXTURE="$PROJECT_ROOT/Examples/http-hls-relay.json"
HLS_SMOKE="$PROJECT_ROOT/Examples/Streaming/local-hls-smoke.sh"

for path in "$PROJECT_ROOT/Package.swift" "$PLAN" "$RELAY_FIXTURE"; do
  [[ -f "$path" ]] || { echo "required file not found: $path" >&2; exit 66; }
done
command -v swift >/dev/null 2>&1 || { echo "swift is required" >&2; exit 69; }

if [[ -n "$OUTPUT_DIR" && "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$PROJECT_ROOT/$OUTPUT_DIR"
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  mkdir -p "$PROJECT_ROOT/.build"
  OUTPUT_DIR="$(mktemp -d "$PROJECT_ROOT/.build/skill-verification.XXXXXX")"
else
  [[ ! -e "$OUTPUT_DIR" ]] || {
    echo "output directory already exists; choose a new path: $OUTPUT_DIR" >&2
    exit 73
  }
  mkdir -p "$OUTPUT_DIR"
  OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
fi
exec > >(tee "$OUTPUT_DIR/verify.log") 2>&1

echo "MonoAudio skill verification"
echo "project_root=$PROJECT_ROOT"
echo "evidence=$OUTPUT_DIR"

swift --version > "$OUTPUT_DIR/environment.txt" 2>&1

echo "[1/5] Building mono-audio"
swift build --package-path "$PROJECT_ROOT" --product mono-audio
BIN_DIR="$(swift build --package-path "$PROJECT_ROOT" --show-bin-path)"
CLI="$BIN_DIR/mono-audio"
[[ -x "$CLI" ]] || { echo "mono-audio executable not found after build" >&2; exit 70; }

echo "[2/5] Validating the neutral plan"
"$CLI" validate "$PLAN" > "$OUTPUT_DIR/validation.json"
grep -q '"issues"' "$OUTPUT_DIR/validation.json" || {
  echo "neutral plan validation did not emit a validation report" >&2
  exit 1
}
if grep -Eq '"severity"[[:space:]]*:[[:space:]]*"error"' "$OUTPUT_DIR/validation.json"; then
  echo "neutral plan validation reported an error" >&2
  exit 1
fi

echo "[3/5] Checking deterministic filtergraph compilation"
"$CLI" filtergraph "$PLAN" > "$OUTPUT_DIR/filtergraph.txt"
"$CLI" filtergraph "$PLAN" > "$OUTPUT_DIR/filtergraph.second.txt"
cmp -s "$OUTPUT_DIR/filtergraph.txt" "$OUTPUT_DIR/filtergraph.second.txt" || {
  echo "filtergraph output changed between identical runs" >&2
  exit 1
}
grep -q 'volume=volume=-0.5dB:precision=float' "$OUTPUT_DIR/filtergraph.txt" || {
  echo "expected neutral-plan preamp was not compiled" >&2
  exit 1
}
grep -q 'alimiter=limit=' "$OUTPUT_DIR/filtergraph.txt" || {
  echo "expected final limiter was not compiled" >&2
  exit 1
}
rm "$OUTPUT_DIR/filtergraph.second.txt"

echo "[4/5] Checking deterministic streaming argv generation"
"$CLI" relay-argv "$RELAY_FIXTURE" > "$OUTPUT_DIR/relay-argv.json"
grep -q '"-nostdin"' "$OUTPUT_DIR/relay-argv.json" || {
  echo "relay argv is missing -nostdin" >&2
  exit 1
}
grep -q '"https://example.com/live/input.m3u8"' "$OUTPUT_DIR/relay-argv.json" || {
  echo "relay input URL was not preserved" >&2
  exit 1
}

echo "[5/5] Inspecting local streaming capabilities"
CAPABILITY_STATUS="skipped (ffmpeg not installed)"
FFMPEG_VALUE="${MONO_AUDIO_FFMPEG:-ffmpeg}"
if FFMPEG_PATH="$(command -v "$FFMPEG_VALUE" 2>/dev/null)"; then
  "$FFMPEG_PATH" -version | sed -n '1p' >> "$OUTPUT_DIR/environment.txt"
  "$CLI" stream-capabilities "$FFMPEG_PATH" > "$OUTPUT_DIR/stream-capabilities.json"
  for field in inputProtocols outputProtocols demuxers muxers encoders; do
    grep -q "\"$field\"" "$OUTPUT_DIR/stream-capabilities.json" || {
      echo "stream capability output is missing $field" >&2
      exit 1
    }
  done
  CAPABILITY_STATUS="passed"
else
  echo "ffmpeg not found; capability inspection skipped"
fi

HLS_STATUS="not requested"
if $RUN_HLS_SMOKE; then
  echo "[optional] Running finite loopback HLS relay"
  [[ -f "$HLS_SMOKE" ]] || { echo "HLS smoke script is missing: $HLS_SMOKE" >&2; exit 66; }
  for tool in ffmpeg ffprobe curl; do
    command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required by --hls-smoke" >&2; exit 69; }
  done
  [[ -x /usr/bin/python3 ]] || { echo "/usr/bin/python3 is required by the HLS smoke fixture" >&2; exit 69; }
  SMOKE_PORT="${MONO_AUDIO_SMOKE_PORT:-18765}"
  if [[ ! "$SMOKE_PORT" =~ ^[0-9]+$ ]] || ((SMOKE_PORT < 1024 || SMOKE_PORT > 65535)); then
    echo "MONO_AUDIO_SMOKE_PORT must be an integer from 1024 through 65535" >&2
    exit 64
  fi
  MONO_AUDIO_SMOKE_PORT="$SMOKE_PORT" \
    bash "$HLS_SMOKE" | tee "$OUTPUT_DIR/hls-smoke.log"
  grep -q 'local HLS relay smoke test passed' "$OUTPUT_DIR/hls-smoke.log" || {
    echo "HLS smoke test did not emit its completion marker" >&2
    exit 1
  }
  HLS_STATUS="passed"
fi

cat > "$OUTPUT_DIR/summary.txt" <<EOF
plan_validation=passed
filtergraph_determinism=passed
relay_argv=passed
stream_capabilities=$CAPABILITY_STATUS
local_hls_smoke=$HLS_STATUS
EOF

CHECKSUM_FILES=(validation.json filtergraph.txt relay-argv.json)
[[ ! -f "$OUTPUT_DIR/stream-capabilities.json" ]] || CHECKSUM_FILES+=(stream-capabilities.json)
if command -v shasum >/dev/null 2>&1; then
  (
    cd "$OUTPUT_DIR"
    shasum -a 256 "${CHECKSUM_FILES[@]}"
  ) > "$OUTPUT_DIR/checksums.sha256"
elif command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$OUTPUT_DIR"
    sha256sum "${CHECKSUM_FILES[@]}"
  ) > "$OUTPUT_DIR/checksums.sha256"
fi

cat "$OUTPUT_DIR/summary.txt"
echo "verification passed"
