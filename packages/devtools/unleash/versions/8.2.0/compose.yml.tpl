image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  # The companion Postgres belongs to this instance alone; see its fragment.
  DATABASE_URL: "postgres://unleash:unleash@{{ companion.postgres.host }}:5432/unleash"
  DATABASE_SSL: "false"
  UNLEASH_URL: "https://unleash.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  UNLEASH_DEFAULT_ADMIN_USERNAME: "{{ settings.ADMIN_USERNAME }}"
  UNLEASH_DEFAULT_ADMIN_PASSWORD: "{{ settings.ADMIN_PASSWORD }}"

ports:
  - "{{ port.main }}:4242"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=4242"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
