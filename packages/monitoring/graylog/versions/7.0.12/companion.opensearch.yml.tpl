image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

environment:
  - discovery.type=single-node
  - cluster.name=stackvo-graylog
  - node.name=opensearch
  - bootstrap.memory_lock=true
  - OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
  # Graylog creates its own indices and index templates; auto-creation on the
  # server writes ones it did not ask for and then disagrees with them.
  - action.auto_create_index=false
  # No demo certificates and no admin password prompt: this node is reachable
  # only from the workspace network, and the security plugin's bootstrap wants
  # a password policy nobody set.
  - DISABLE_INSTALL_DEMO_CONFIG=true
  - DISABLE_SECURITY_PLUGIN=true

ulimits:
  memlock: -1
  nofile: 65536

volumes:
  - "{{ companion.volume.data }}:/usr/share/opensearch/data"

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
