image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  ELASTICSEARCH_HOSTS: "{{ settings.ELASTICSEARCH_HOSTS }}"
  SERVER_NAME: "{{ settings.SERVER_NAME }}"
  SERVER_HOST: "{{ settings.SERVER_HOST }}"

volumes:
  - "{{ volume.data }}:/usr/share/kibana/data"
  - "{{ instance.logs }}:/usr/share/kibana/logs"

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
