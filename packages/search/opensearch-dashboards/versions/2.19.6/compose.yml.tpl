image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  OPENSEARCH_HOSTS: '["{{ settings.OPENSEARCH_HOSTS }}"]'
  # The OpenSearch package runs with its security plugin off, so the matching
  # dashboards plugin has to be off too or the UI waits for a login that
  # cannot happen.
  DISABLE_SECURITY_DASHBOARDS_PLUGIN: "true"
  SERVER_HOST: "{{ settings.SERVER_HOST }}"

volumes:
  - "{{ instance.logs }}:/usr/share/opensearch-dashboards/logs"

ports:
  - "{{ port.main }}:5601"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=5601"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
