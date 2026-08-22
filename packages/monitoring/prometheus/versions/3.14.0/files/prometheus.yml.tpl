###################################################################
# STACKVO PROMETHEUS CONFIG TEMPLATE
###################################################################

global:
  scrape_interval: {{ settings.SCRAPE_INTERVAL }}
  evaluation_interval: {{ settings.EVALUATION_INTERVAL }}
  external_labels:
    monitor: stackvo

# Prometheus scrapes itself and nothing else, because what else is on the
# workspace network is a per-machine question. Add a job here — or point the
# server at a file it reloads — rather than editing the rendered copy under
# generated/, which is rewritten on every run.
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["127.0.0.1:9090"]
