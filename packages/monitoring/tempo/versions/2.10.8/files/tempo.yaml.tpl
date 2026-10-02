###################################################################
# STACKVO TEMPO CONFIG TEMPLATE
###################################################################

# Single binary, local storage. Send OTLP traces to port 4317 (gRPC) or 4318
# (HTTP) -- the OpenTelemetry Collector package does. Add Tempo in Grafana as a
# data source with URL http://stackvo-tempo:3200.

stream_over_http_enabled: true

server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

compactor:
  compaction:
    block_retention: {{ settings.RETENTION_PERIOD }}

storage:
  trace:
    backend: local
    wal:
      path: /var/tempo/wal
    local:
      path: /var/tempo/blocks

usage_report:
  reporting_enabled: false
