image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# Development mode: in-memory storage, auto-unsealed, plain HTTP, one root
# token. Everything is lost when the container stops; this is not a vault to
# keep secrets in.
environment:
  SKIP_SETCAP: "true"
  BAO_DEV_ROOT_TOKEN_ID: "{{ settings.ROOT_TOKEN }}"
  BAO_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"

ports:
  - "{{ port.main }}:8200"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8200"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
