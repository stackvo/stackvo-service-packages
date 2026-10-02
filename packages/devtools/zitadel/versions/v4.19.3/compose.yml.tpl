image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# start-from-init creates the database, runs setup and serves. TLS ends at
# Traefik, which talks h2c to the container.
command:
  - "start-from-init"
  - "--masterkeyFromEnv"
  - "--tlsMode"
  - "external"

environment:
  ZITADEL_MASTERKEY: "{{ settings.MASTERKEY }}"
  ZITADEL_EXTERNALDOMAIN: "zitadel.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  ZITADEL_EXTERNALPORT: "443"
  ZITADEL_EXTERNALSECURE: "true"
  ZITADEL_TLS_ENABLED: "false"
  # The companion Postgres belongs to this instance alone; see its fragment.
  ZITADEL_DATABASE_POSTGRES_HOST: "{{ companion.postgres.host }}"
  ZITADEL_DATABASE_POSTGRES_PORT: "5432"
  ZITADEL_DATABASE_POSTGRES_DATABASE: "zitadel"
  ZITADEL_DATABASE_POSTGRES_USER_USERNAME: "zitadel"
  ZITADEL_DATABASE_POSTGRES_USER_PASSWORD: "zitadel"
  ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE: "disable"
  ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME: "zitadel"
  ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD: "zitadel"
  ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE: "disable"
  ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME: "{{ settings.ADMIN_USERNAME }}"
  ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD: "{{ settings.ADMIN_PASSWORD }}"
  ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORDCHANGEREQUIRED: "false"
  # v4 can hand sign-in to the separate Login V2 container; this package ships
  # one container, so it keeps the login UI the core binary serves.
  ZITADEL_DEFAULTINSTANCE_FEATURES_LOGINV2_REQUIRED: "false"

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
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.scheme=h2c"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
