# Python + Julia, two processes in one image (implementation plan §2.1).
FROM julia:1.11-bookworm AS julia-base

FROM python:3.12-slim-bookworm
COPY --from=julia-base /usr/local/julia /usr/local/julia
ENV PATH="/usr/local/julia/bin:${PATH}" JULIA_DEPOT_PATH=/opt/julia-depot

WORKDIR /app
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir .

COPY julia ./julia
RUN julia --project=/app/julia -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && useradd -r -m app && chown -R app /opt/julia-depot
USER app
ENV PORT=8082
EXPOSE 8082
ENTRYPOINT ["/entrypoint.sh"]
