image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

volumes:
  - "{{ volume.data }}:/qdrant/storage"

ports:
  - "{{ port.http }}:6333"
  - "{{ port.grpc }}:6334"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=6333"
