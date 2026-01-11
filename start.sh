#!/usr/bin/env bash
set -euo pipefail

: "${INPUT_URL:?INPUT_URL is required}"
: "${RTMP_URL:?RTMP_URL is required}"

REFERER_HEADER="${REFERER_HEADER:-}"
ORIGIN_HEADER="${ORIGIN_HEADER:-}"
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36}"
HLS_COOKIE="${HLS_COOKIE:-}"

WATERMARK_TEXT="${WATERMARK_TEXT:-TipiStream}"
FONT_SIZE="${FONT_SIZE:-24}"
X_POS="${X_POS:-180}"
Y_POS="${Y_POS:-180}"

VIDEO_PRESET="${VIDEO_PRESET:-veryfast}"
AUDIO_BITRATE="${AUDIO_BITRATE:-128k}"
RESTART_DELAY="${RESTART_DELAY:-5}"

echo "==== Zeabur FFmpeg Stream Runner ===="
echo "INPUT_URL: $INPUT_URL"
echo "RTMP_URL: (hidden)"
echo "USER_AGENT: $USER_AGENT"
echo "====================================="

while true; do
  echo ""
  echo "[INFO] Starting stream at $(date -Iseconds)"

  # ====== Build EXTRA headers only ======
  # NOTE: Do NOT put Referer/User-Agent here (use -referer and -user_agent)
  EXTRA_HDR="Accept: */*\r\nAccept-Language: en-US,en;q=0.9\r\nConnection: keep-alive\r\n"

  # Origin is not supported via native option, so put it here if provided
  if [ -n "$ORIGIN_HEADER" ]; then
    EXTRA_HDR="${EXTRA_HDR}Origin: ${ORIGIN_HEADER}\r\n"
  fi

  # Final CRLF (IMPORTANT)
  EXTRA_HDR="${EXTRA_HDR}\r\n"

  # Optional debug access with curl:
  echo "[INFO] curl check (first 10 lines)"
  curl -I -L "$INPUT_URL" \
    -A "$USER_AGENT" \
    ${REFERER_HEADER:+-e "$REFERER_HEADER"} \
    ${ORIGIN_HEADER:+-H "Origin: $ORIGIN_HEADER"} \
    ${HLS_COOKIE:+-H "Cookie: $HLS_COOKIE"} \
    | head -n 10 || true

  # ====== Run ffmpeg ======
  echo "[INFO] Running ffmpeg..."
  ffmpeg -hide_banner -loglevel warning \
    -re \
    -user_agent "$USER_AGENT" \
    ${REFERER_HEADER:+-referer "$REFERER_HEADER"} \
    ${HLS_COOKIE:+-cookies "$HLS_COOKIE"} \
    -headers "$EXTRA_HDR" \
    -i "$INPUT_URL" \
    -vf "drawtext=text='${WATERMARK_TEXT}':fontcolor=white:fontsize=${FONT_SIZE}:x=${X_POS}:y=${Y_POS}" \
    -c:v libx264 -preset "$VIDEO_PRESET" -tune zerolatency \
    -c:a aac -b:a "$AUDIO_BITRATE" -ar 44100 \
    -f flv "$RTMP_URL" || true

  echo "[WARN] ffmpeg stopped. Restarting in ${RESTART_DELAY}s..."
  sleep "$RESTART_DELAY"
done
