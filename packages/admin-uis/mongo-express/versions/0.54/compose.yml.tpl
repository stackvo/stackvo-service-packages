image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  ME_CONFIG_MONGODB_SERVER: "{{ settings.MONGODB_SERVER }}"
  ME_CONFIG_MONGODB_PORT: "{{ settings.MONGODB_PORT }}"
  ME_CONFIG_MONGODB_ADMINUSERNAME: "{{ settings.ADMIN_USERNAME }}"
  ME_CONFIG_MONGODB_ADMINPASSWORD: "{{ settings.ADMIN_PASSWORD }}"
  ME_CONFIG_BASICAUTH_USERNAME: "{{ settings.BASICAUTH_USERNAME }}"
  ME_CONFIG_BASICAUTH_PASSWORD: "{{ settings.BASICAUTH_PASSWORD }}"
  ME_CONFIG_SITE_BASEURL: "{{ settings.BASEURL }}"

volumes:
  - "{{ instance.logs }}:/var/log/mongo-express"

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
