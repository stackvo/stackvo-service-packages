image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  NEO4J_AUTH: "neo4j/{{ settings.PASSWORD }}"

volumes:
  - "{{ volume.data }}:/data"
  - "{{ instance.logs }}:/logs"

ports:
  - "{{ port.http }}:7474"
  - "{{ port.bolt }}:7687"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=7474"
