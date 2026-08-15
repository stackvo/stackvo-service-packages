image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  CLICKHOUSE_DB: "{{ settings.DB }}"
  CLICKHOUSE_USER: "{{ settings.USER }}"
  CLICKHOUSE_PASSWORD: "{{ settings.PASSWORD }}"
  # Without this the named user is created with no grants, so the credentials
  # in the connection string authenticate and then cannot read the database
  # they were issued for.
  CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT: "1"

# ClickHouse opens a file per part and refuses to start on the 1024 a container
# gets by default. The server's own packaging sets this; a compose file that
# leaves it out gets a container that exits during startup.
ulimits:
  nofile:
    soft: 262144
    hard: 262144

volumes:
  - "{{ volume.data }}:/var/lib/clickhouse"

ports:
  - "{{ port.http }}:8123"
  - "{{ port.native }}:9000"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8123"
