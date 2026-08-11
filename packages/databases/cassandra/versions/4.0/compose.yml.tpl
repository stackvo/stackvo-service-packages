image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  CASSANDRA_CLUSTER_NAME: "{{ settings.CLUSTER_NAME }}"
  CASSANDRA_DC: "{{ settings.DC }}"
  CASSANDRA_RACK: "{{ settings.RACK }}"
  CASSANDRA_ENDPOINT_SNITCH: "{{ settings.ENDPOINT_SNITCH }}"
  MAX_HEAP_SIZE: "{{ settings.MAX_HEAP_SIZE }}"
  HEAP_NEWSIZE: "{{ settings.HEAP_NEWSIZE }}"

volumes:
  - "{{ volume.data }}:/var/lib/cassandra"
  - "{{ instance.logs }}:/var/log/cassandra"

ports:
  - "{{ port.main }}:9042"
  - "{{ port.jmx }}:7199"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

healthcheck:
  test: ["CMD-SHELL", "cqlsh -e 'describe cluster'"]
  interval: 30s
  timeout: 10s
  retries: 5
