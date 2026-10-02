image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  - discovery.type=single-node
  - cluster.name=stackvo-opensearch
  - node.name=opensearch
  - network.host=0.0.0.0
  - bootstrap.memory_lock=true
  - OPENSEARCH_JAVA_OPTS={{ settings.OPENSEARCH_JAVA_OPTS }}
  # No demo certificates and no admin password prompt: the node is reachable
  # only from the workspace network and the loopback port, over plain HTTP.
  - DISABLE_INSTALL_DEMO_CONFIG=true
  - DISABLE_SECURITY_PLUGIN=true

ulimits:
  memlock: -1
  nofile: 65536

volumes:
  - "{{ volume.data }}:/usr/share/opensearch/data"

ports:
  - "{{ port.main }}:9200"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
