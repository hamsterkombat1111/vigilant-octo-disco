FROM golang:1.24-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/telesrv ./cmd/telesrv
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/telesrv-admin ./cmd/telesrv-admin

FROM alpine:3.20

WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata bash curl

COPY --from=builder /app/telesrv /app/telesrv
COPY --from=builder /app/telesrv-admin /app/telesrv-admin
COPY --from=builder /app/deploy /app/deploy
COPY --from=builder /app/data /app/data

EXPOSE 2600 2398

RUN echo '#!/bin/bash' > /app/entrypoint.sh && \
    echo 'set -e' >> /app/entrypoint.sh && \
    echo 'echo "Starting Telesrv backend..."' >> /app/entrypoint.sh && \
    echo '/app/telesrv &' >> /app/entrypoint.sh && \
    echo 'TELESRV_PID=$!' >> /app/entrypoint.sh && \
    echo 'echo "Starting Telesrv Admin on port ${PORT:-2600}..."' >> /app/entrypoint.sh && \
    echo 'export TELESRV_ADMIN_UI_ADDR="0.0.0.0:${PORT:-2600}"' >> /app/entrypoint.sh && \
    echo '/app/telesrv-admin &' >> /app/entrypoint.sh && \
    echo 'ADMIN_PID=$!' >> /app/entrypoint.sh && \
    echo 'wait -n $TELESRV_PID $ADMIN_PID' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
