FROM rust:1.90-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* && useradd -r app
COPY --from=build /src/target/release/review-api /usr/local/bin/review-api
ENV PORT=8083
USER app
EXPOSE 8083
ENTRYPOINT ["review-api"]
