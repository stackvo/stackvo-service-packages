# Redpanda Connect stream config, rendered by StackVo.
#
# A starting point, not a recipe: it accepts JSON on POST /post, stamps it and
# prints it to the container log (`docker logs <instance>`). Replace the
# input / pipeline / output blocks with your own.
http:
  enabled: true
  address: 0.0.0.0:4195

input:
  http_server:
    path: /post

pipeline:
  processors:
    - mapping: |
        root = this
        root.received_at = now()

output:
  stdout: {}

logger:
  level: {{ settings.LOG_LEVEL }}
  format: logfmt
