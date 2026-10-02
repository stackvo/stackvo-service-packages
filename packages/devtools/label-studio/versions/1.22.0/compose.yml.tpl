image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  LABEL_STUDIO_USERNAME: "{{ settings.USERNAME }}"
  LABEL_STUDIO_PASSWORD: "{{ settings.PASSWORD }}"
  LABEL_STUDIO_HOST: "https://label-studio.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  LABEL_STUDIO_DISABLE_SIGNUP_WITHOUT_LINK: "true"

volumes:
  - "{{ volume.data }}:/label-studio/data"

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
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
