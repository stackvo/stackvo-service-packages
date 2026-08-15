image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# The entrypoint creates the core on first boot and then hands over to Solr
# itself. `solr-precreate` is a no-op when the core already exists, so this
# survives a restart without a second core or a refusal.
command: ["solr-precreate", "{{ settings.CORE }}"]

environment:
  SOLR_HEAP: "{{ settings.SOLR_HEAP }}"

volumes:
  - "{{ volume.data }}:/var/solr"

ports:
  - "{{ port.main }}:8983"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8983"
