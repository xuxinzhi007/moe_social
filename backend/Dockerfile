# Stage 1: Build
FROM golang:1.25.5-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Set GOPROXY for faster dependency download
ENV GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on

# Download dependencies
RUN go mod download

# Copy all source files
COPY . .

# Build the API service
RUN go build -o api ./api

# Build the RPC service
RUN go build -o rpc ./rpc

# Stage 2: Final
FROM alpine:latest

WORKDIR /app

# Install ca-certificates for HTTPS requests
RUN apk add --no-cache ca-certificates

# Copy built binaries from builder stage
COPY --from=builder /app/api /app/api
COPY --from=builder /app/rpc /app/rpc

# Copy configuration files
COPY api/etc/super.yaml /app/etc/super.yaml
COPY rpc/etc/super.yaml /app/rpc/etc/super.yaml
COPY config/config.yaml /app/config/config.yaml

# Create necessary directories
RUN mkdir -p /app/data/images

# Expose the API port
EXPOSE 8888
# Expose the RPC port
EXPOSE 8080

# Set environment variables
ENV GIN_MODE=release

# Create start script
RUN echo '#!/bin/sh
# Start RPC service in background
./rpc -f rpc/etc/super.yaml &

# Start API service in foreground
./api -f etc/super.yaml' > /app/start.sh && chmod +x /app/start.sh

# Run the start script
CMD ["/app/start.sh"]