image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  # The upstream demo image's production config reads its database from these.
  # The database is a service of its own, so it is named rather than shipped:
  # a workspace running PostgreSQL already has the one Backstage needs.
  POSTGRES_HOST: "{{ settings.POSTGRES_HOST }}"
  POSTGRES_PORT: "{{ settings.POSTGRES_PORT }}"
  POSTGRES_USER: "{{ settings.POSTGRES_USER }}"
  POSTGRES_PASSWORD: "{{ settings.POSTGRES_PASSWORD }}"
  # The image bakes in http://localhost:7007; the browser reaches it through
  # Traefik, so the frontend, the backend and CORS all have to say so.
  APP_CONFIG_app_baseUrl: "https://backstage.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  APP_CONFIG_backend_baseUrl: "https://backstage.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  APP_CONFIG_backend_cors_origin: "https://backstage.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"

ports:
  - "{{ port.main }}:7007"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=7007"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
