###################################################################
# STACKVO OPENTELEMETRY COLLECTOR CONFIG TEMPLATE
###################################################################

# Applications send OTLP to port 4317 (gRPC) or 4318 (HTTP). Traces go to
# Tempo, logs go to Loki, and metrics are exposed on :8889/metrics for
# Prometheus to scrape. Backends that are not running only make the exporter
# retry and log; the collector itself still starts. Edit the endpoints under
# the instance's settings rather than the rendered copy under generated/.

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: {{ settings.MEMORY_LIMIT_MIB }}
  batch: {}

exporters:
  otlp_grpc/tempo:
    endpoint: {{ settings.TEMPO_ENDPOINT }}
    tls:
      insecure: true
  otlp_http/loki:
    endpoint: {{ settings.LOKI_ENDPOINT }}
    tls:
      insecure: true
  prometheus:
    endpoint: 0.0.0.0:8889
  debug:
    verbosity: basic

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_grpc/tempo]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_http/loki]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
  telemetry:
    metrics:
      level: none
