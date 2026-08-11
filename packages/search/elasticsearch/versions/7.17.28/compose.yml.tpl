image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  - discovery.type=single-node
  - ES_JAVA_OPTS={{ settings.ES_JAVA_OPTS }}
  - xpack.security.enabled={{ settings.ELASTIC_SECURITY }}
  - xpack.security.enrollment.enabled={{ settings.ELASTIC_ENROLLMENT }}
  - cluster.name=stackvo-es
  - network.host=0.0.0.0
  # Redirect logs to stdout/stderr - accessible via Docker logs
  - "logger.level=info"

ulimits:
  memlock: -1
  nofile: 65536

volumes:
  - "{{ volume.data }}:/usr/share/elasticsearch/data"
  - "{{ file.elasticsearch_yml }}:/usr/share/elasticsearch/config/elasticsearch.yml:ro"
  # Log volume mount removed - to prevent permission issues

ports:
  - "{{ port.main }}:9200"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
