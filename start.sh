#!/usr/bin/env bash
set -euo pipefail

# ==========
# REQUIRED ENV
# ==========
: "${INPUT_URL:?INPUT_URL is required}"
: "${RTMP_URL:?RTMP_URL is required}"

# ==========
# OPTIONAL ENV
# ==========
REFERER_HEADER="${REFERER_HEADER:-}"
ORIGIN_HEADER="${ORIGIN_HEADER:-}"
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36}"
HLS_COOKIE="${HLS_COOKIE:-}"

# Watermark settings
WATERMARK_TEXT="${WATERMARK_TEXT:-TipiStream}"
FONT_SIZE="${FONT_SIZE:-24}"
X_POS="${X_POS:-180}"
Y_POS="${Y_POS:-180}"

# Encoding settings
VIDEO_PRESET="${VIDEO_PRESET:-veryfast}"
AUDIO_BITRATE="${AUDIO_BITRATE:-128k}"
RESTART_DELAY="${RESTART_DELAY:-5}"

echo "==== ENV CHECK ===="
echo "INPUT_URL: $INPUT_URL"
echo "RTMP_URL: (hidden)"
echo "UA: $USER_AGENT"
echo "==================="

# Mask (avoid leaking in logs)
echo ":: RTMP_URL masked ::"

build_headers() {
  HDR=""

  # Urutan header sesuai request: Referer -> Origin -> User-Agent
  if [ -n "$REFERER_HEADER" ]; then
    HDR="${HDR}Referer: ${REFERER_HEADER}\r\n"
  fi
  if [ -n "$ORIGIN_HEADER" ]; then
    HDR="${HDR}Origin: ${ORIGIN_HEADER}\r\n"
  fi
  if [ -n "$USER_AGENT" ]; then
    HDR="${HDR}User-Agent: ${USER_AGENT}\r\n"
  fi

  # Browser-like headers
  HDR="${HDR}Accept: */*\r\n"
  HDR="${HDR}Accept-Language: en-US,en;q=0.9\r\n"
  HDR="${HDR}Connection: keep-alive\r\n"

  if [ -n "$HLS_COOKIE" ]; then
    HDR="${HDR}Cookie: ${HLS_COOKIE}\r\n"
  fi

  # Final CRLF (penting)
  HDR="${HDR}\r\n"

  echo -e "$HDR"
}

while true; do
  echo ""
  echo "[INFO] Starting stream loop at $(date -Iseconds)"

  HDR="$(build_headers)"

  # Optional: quick check (doesn't stop script if fails)
  echo "[INFO] Checking access..."
  curl -I -L "$INPUT_URL" \
    -H "User-Agent: $USER_AGENT" \
    ${REFERER_HEADER:+-H "Referer: $REFERER_HEADER"} \
    ${ORIGIN_HEADER:+-H "Origin: $ORIGIN_HEADER"} \
    ${HLS_COOKIE:+-H "Cookie: $HLS_COOKIE"} \
    | head -n 20 || true

  echo "[INFO] Running ffmpeg..."
  ffmpeg -hide_banner -loglevel warning \
    -re \
    -user_agent "$USER_AGENT" \
    -headers "$HDR" \
    -i "$INPUT_URL" \
    -vf "drawtext=text='${WATERMARK_TEXT}':fontcolor=white:fontsize=${FONT_SIZE}:x=${X_POS}:y=${Y_POS}" \
    -c:v libx264 -preset "$VIDEO_PRESET" -tune zerolatency \
    -c:a aac -b:a "$AUDIO_BITRATE" -ar 44100 \
    -f flv "$RTMP_URL" || true

  echo "[WARN] ffmpeg stopped / crashed. Restarting in ${RESTART_DELAY}s..."
  sleep "$RESTART_DELAY"
done
