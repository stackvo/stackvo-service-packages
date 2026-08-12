image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  RABBITMQ_DEFAULT_USER: "{{ settings.DEFAULT_USER }}"
  RABBITMQ_DEFAULT_PASS: "{{ settings.DEFAULT_PASS }}"
  RABBITMQ_DEFAULT_VHOST: "/"

volumes:
  - "{{ volume.data }}:/var/lib/rabbitmq"
  - "{{ volume.logs }}:/var/log/rabbitmq"

ports:
  - "{{ port.main }}:5672"
  - "{{ port.mgmt }}:15672"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=15672"
