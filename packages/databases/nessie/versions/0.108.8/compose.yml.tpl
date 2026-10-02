image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  # The default store is in memory and forgets every branch on restart; RocksDB
  # keeps the catalogue on the instance's volume without needing a database.
  NESSIE_VERSION_STORE_TYPE: "ROCKSDB"
  NESSIE_VERSION_STORE_PERSIST_ROCKS_DATABASE_PATH: "/deployments/data"

volumes:
  - "{{ volume.data }}:/deployments/data"

ports:
  - "{{ port.http }}:19120"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=19120"
