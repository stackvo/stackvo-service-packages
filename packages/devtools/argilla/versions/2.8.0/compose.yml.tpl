image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  # The server runs its migrations, creates the owner below on first boot and
  # then waits for the search engine; all three stores travel with the instance
  # as companions, because none of them is meant to be shared with another service.
  ARGILLA_DATABASE_URL: "postgresql+asyncpg://argilla:argilla@{{ companion.postgres.host }}:5432/argilla"
  ARGILLA_ELASTICSEARCH: "http://{{ companion.elasticsearch.host }}:9200"
  ARGILLA_REDIS_URL: "redis://{{ companion.redis.host }}:6379/0"
  ARGILLA_AUTH_SECRET_KEY: "{{ settings.AUTH_SECRET_KEY }}"
  USERNAME: "{{ settings.USERNAME }}"
  PASSWORD: "{{ settings.PASSWORD }}"
  API_KEY: "{{ settings.API_KEY }}"

ports:
  - "{{ port.main }}:6900"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=6900"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
