image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command:
  - "--config.file=/etc/prometheus/prometheus.yml"
  - "--storage.tsdb.path=/prometheus"
  - "--storage.tsdb.retention.time={{ settings.RETENTION_TIME }}"
  - "--web.enable-lifecycle"
  - "--web.external-url=https://prometheus.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}/"
  - "--web.route-prefix=/"

volumes:
  - "{{ volume.data }}:/prometheus"
  - "{{ file.prometheus_yml }}:/etc/prometheus/prometheus.yml:ro"

ports:
  - "{{ port.main }}:9090"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=9090"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
