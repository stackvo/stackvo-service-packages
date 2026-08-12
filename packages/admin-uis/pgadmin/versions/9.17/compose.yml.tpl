image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  PGADMIN_DEFAULT_EMAIL: "{{ settings.DEFAULT_EMAIL }}"
  PGADMIN_DEFAULT_PASSWORD: "{{ settings.DEFAULT_PASSWORD }}"
  PGADMIN_CONFIG_SERVER_MODE: "{{ settings.SERVER_MODE }}"
  PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: "{{ settings.MASTER_PASSWORD_REQUIRED }}"

volumes:
  - "{{ volume.data }}:/var/lib/pgadmin"
  - "{{ instance.logs }}:/var/log/pgadmin"

ports:
  - "{{ port.main }}:80"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=80"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
