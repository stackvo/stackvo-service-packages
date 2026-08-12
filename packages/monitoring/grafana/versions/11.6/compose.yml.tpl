image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  GF_SECURITY_ADMIN_USER: "{{ settings.ADMIN_USER }}"
  GF_SECURITY_ADMIN_PASSWORD: "{{ settings.ADMIN_PASSWORD }}"
  GF_INSTALL_PLUGINS: ""
  GF_SERVER_ROOT_URL: "http://grafana.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"

volumes:
  - "{{ volume.data }}:/var/lib/grafana"
  - "{{ volume.config }}:/etc/grafana"
  - "{{ instance.logs }}:/var/log/grafana"

ports:
  - "{{ port.main }}:3000"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

user: "{{ settings.HOST_UID }}"

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=3000"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
