image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command: server /data --console-address ":9001"

environment:
  MINIO_ROOT_USER: "{{ settings.ROOT_USER }}"
  MINIO_ROOT_PASSWORD: "{{ settings.ROOT_PASSWORD }}"
  MINIO_REGION: "{{ settings.REGION }}"
  # Off by default for the reason PRIVACY.md gives for the app itself.
  MINIO_UPDATE: "off"

volumes:
  - "{{ volume.data }}:/data"

ports:
  - "{{ port.main }}:9000"
  - "{{ port.console }}:9001"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=9001"
