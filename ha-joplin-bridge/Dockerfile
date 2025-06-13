ARG TARGETARCH
FROM ghcr.io/home-assistant/${TARGETARCH}-base:latest

# Install dependencies
RUN apk add --no-cache \
    nodejs \
    npm \
    bash \
    curl \
    jq \
    tzdata \
    socat \
    python3 \
    py3-flask

# Create user
RUN addgroup -g 1000 joplin && \
    adduser -D -s /bin/bash -u 1000 -G joplin joplin

# Install Joplin CLI
RUN npm install -g joplin

# Create directories
RUN mkdir -p /data/joplin
RUN chown -R joplin:joplin /data/joplin

# Copy files
COPY run.sh /run.sh
COPY api_server.py /api_server.py
RUN chmod +x /run.sh

WORKDIR /data/joplin

# Export ports
EXPOSE 41184 41185 41186

# Start
CMD ["/run.sh"]