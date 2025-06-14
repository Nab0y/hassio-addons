ARG BUILD_FROM
FROM $BUILD_FROM

# Install dependencies
RUN apk add --no-cache \
    nodejs \
    npm \
    bash \
    curl \
    jq \
    tzdata \
    python3 \
    py3-flask \
    py3-pip

# Install bashio (Home Assistant helper)
RUN pip3 install --no-cache-dir bashio

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
EXPOSE 41184 41186

# Start
CMD ["/run.sh"]