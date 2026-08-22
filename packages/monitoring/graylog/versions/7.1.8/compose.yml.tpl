image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  GRAYLOG_PASSWORD_SECRET: "{{ settings.PASSWORD_SECRET }}"
  GRAYLOG_ROOT_USERNAME: "{{ settings.ROOT_USERNAME }}"
  GRAYLOG_ROOT_PASSWORD_SHA2: "{{ settings.ROOT_PASSWORD_SHA2 }}"
  GRAYLOG_ROOT_TIMEZONE: "{{ settings.TIMEZONE }}"
  GRAYLOG_HTTP_BIND_ADDRESS: "0.0.0.0:9000"
  GRAYLOG_HTTP_EXTERNAL_URI: "https://graylog.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}/"
  # The metadata store is a service of its own, so it is named rather than
  # shipped: a workspace running Mongo already has the one Graylog needs.
  GRAYLOG_MONGODB_URI: "{{ settings.MONGODB_URI }}"
  # The message store is not. Graylog 6 and 7 take OpenSearch 2.x, which is not
  # in this catalogue as a package — so it travels with the instance instead,
  # named against it rather than shared.
  GRAYLOG_ELASTICSEARCH_HOSTS: "http://{{ companion.opensearch.host }}:9200"

volumes:
  - "{{ volume.data }}:/usr/share/graylog/data"

ports:
  - "{{ port.main }}:9000"
  - "{{ port.gelf }}:12201/udp"
  - "{{ port.syslog }}:1514"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=9000"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
