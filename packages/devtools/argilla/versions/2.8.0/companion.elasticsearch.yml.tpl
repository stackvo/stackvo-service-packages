image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

environment:
  - discovery.type=single-node
  - cluster.name=stackvo-argilla
  - ES_JAVA_OPTS=-Xms512m -Xmx512m
  - xpack.security.enabled=false
  - xpack.security.enrollment.enabled=false

ulimits:
  memlock: -1
  nofile: 65536

volumes:
  - "{{ companion.volume.data }}:/usr/share/elasticsearch/data"

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
