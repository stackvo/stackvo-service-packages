image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  TYPESENSE_API_KEY: "{{ settings.API_KEY }}"
  TYPESENSE_DATA_DIR: /data
  # A browser front end queries Typesense directly, from a different
  # origin than the one it was served from.
  TYPESENSE_ENABLE_CORS: "true"

volumes:
  - "{{ volume.data }}:/data"

ports:
  - "{{ port.main }}:8108"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8108"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
