FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    ffmpeg ca-certificates curl bash \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Zeabur biasanya expose PORT, tapi kita tidak butuh server http.
# Jadi tidak perlu EXPOSE.

CMD ["/app/start.sh"]
