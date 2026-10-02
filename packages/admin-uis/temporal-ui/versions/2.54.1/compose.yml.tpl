image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  TEMPORAL_ADDRESS: "{{ settings.TEMPORAL_ADDRESS }}"
  TEMPORAL_DEFAULT_NAMESPACE: "{{ settings.DEFAULT_NAMESPACE }}"
  TEMPORAL_CORS_ORIGINS: "https://temporal-ui.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"

ports:
  - "{{ port.main }}:8080"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8080"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
