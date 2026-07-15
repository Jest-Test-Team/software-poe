# Build context: repository root (needs db/migrations).
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY services/gateway-api/go.mod services/gateway-api/go.sum ./
RUN go mod download
COPY services/gateway-api/ ./
RUN CGO_ENABLED=0 go build -o /out/gateway-api .

FROM alpine:3.20
RUN addgroup -S app && adduser -S app -G app
COPY --from=build /out/gateway-api /usr/local/bin/gateway-api
COPY db/migrations /app/migrations
ENV MIGRATIONS_DIR=/app/migrations PORT=8081 GIN_MODE=release
USER app
EXPOSE 8081
ENTRYPOINT ["gateway-api"]
