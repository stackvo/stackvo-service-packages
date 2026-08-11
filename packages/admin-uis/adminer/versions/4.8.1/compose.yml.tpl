image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  ADMINER_DEFAULT_SERVER: "{{ settings.DEFAULT_SERVER }}"
  ADMINER_DESIGN: "{{ settings.DESIGN }}"

volumes:
  - "{{ instance.logs }}:/var/log/adminer"

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
