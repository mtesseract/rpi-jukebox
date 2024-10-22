# Specification for images to be shipped.

FROM lukemathwalker/cargo-chef:0.1.68-rust-slim-bookworm AS chef
RUN apt-get update && \
	apt-get -y install \
		binutils \
		gcc \
		curl \
		build-essential \
		libasound2-dev \
		pkg-config
WORKDIR /proj

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /proj/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
RUN cargo build --release
RUN rm -rf out && \
	mkdir -p out/bin && \
	cp target/release/jukebox out/bin

FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get -y install tini libasound2
WORKDIR /app
COPY --from=builder /proj/out/ /app
COPY scripts/jukebox-wrapper /app/bin/jukebox-wrapper
ENTRYPOINT ["/usr/bin/tini", "--"]
