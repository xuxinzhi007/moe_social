# 单进程 Kratos HTTP 生产镜像
FROM golang:1.25.5-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
ENV GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o moe-social ./cmd/moe-social

FROM alpine:latest
WORKDIR /app
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/moe-social /app/moe-social
COPY api/etc/moe.yaml /app/api/etc/moe.yaml
COPY config/config.yaml /app/config/config.yaml
RUN mkdir -p /app/data/images
EXPOSE 8888
CMD ["/app/moe-social", "-f", "config/config.yaml"]
