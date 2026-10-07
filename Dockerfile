# CLIProxyAPI in Docker — pull latest release binary
FROM alpine:3.21

RUN apk add --no-cache ca-certificates curl tzdata

# Fetch latest CLIProxyAPI binary from GitHub releases
# Adjust VERSION if you need a specific release
ARG VERSION=latest
RUN if [ "$VERSION" = "latest" ]; then \
      curl -sL "https://github.com/router-for-me/CLIProxyAPI/releases/latest/download/cli-proxy-api-linux-amd64" -o /app/cli-proxy-api; \
    else \
      curl -sL "https://github.com/router-for-me/CLIProxyAPI/releases/download/${VERSION}/cli-proxy-api-linux-amd64" -o /app/cli-proxy-api; \
    fi && \
    chmod +x /app/cli-proxy-api

WORKDIR /app
EXPOSE 8317

CMD ["./cli-proxy-api", "--config", "/app/config/config.yaml"]