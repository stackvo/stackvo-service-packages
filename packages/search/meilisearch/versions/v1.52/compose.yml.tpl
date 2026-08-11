image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  MEILI_MASTER_KEY: "{{ settings.MASTER_KEY }}"
  MEILI_ENV: "development"
  MEILI_DB_PATH: /meili_data
  # Meilisearch reports usage to its vendor unless told otherwise.
  MEILI_NO_ANALYTICS: "true"

volumes:
  - "{{ volume.data }}:/meili_data"

ports:
  - "{{ port.main }}:7700"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=7700"
