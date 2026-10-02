image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command: jobmanager

environment:
  FLINK_PROPERTIES: |
    jobmanager.rpc.address: {{ instance.container }}
    jobmanager.bind-host: 0.0.0.0
    jobmanager.memory.process.size: {{ settings.JOBMANAGER_MEMORY }}
    rest.bind-address: 0.0.0.0

ports:
  - "{{ port.main }}:8081"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8081"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
