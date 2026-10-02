image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  ICECAST_SOURCE_PASSWORD: "{{ settings.SOURCE_PASSWORD }}"
  ICECAST_RELAY_PASSWORD: "{{ settings.RELAY_PASSWORD }}"
  ICECAST_ADMIN_USERNAME: "{{ settings.ADMIN_USERNAME }}"
  ICECAST_ADMIN_PASSWORD: "{{ settings.ADMIN_PASSWORD }}"
  ICECAST_HOSTNAME: "{{ settings.HOSTNAME }}"
  ICECAST_MAX_CLIENTS: "{{ settings.MAX_CLIENTS }}"
  ICECAST_MAX_SOURCES: "{{ settings.MAX_SOURCES }}"

ports:
  - "{{ port.main }}:8000"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8000"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
