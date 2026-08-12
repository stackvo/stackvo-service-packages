image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  # Redis server configuration (PCA_ prefix required)
  PCA_REDIS_0_HOST: "{{ settings.REDIS_HOST }}"
  PCA_REDIS_0_PORT: "{{ settings.REDIS_PORT }}"
  PCA_REDIS_0_CLIENT: "predis"  # Use Predis library instead of PHP Redis extension

  # Memcached server configuration (PCA_ prefix required)
  PCA_MEMCACHED_0_HOST: "{{ settings.MEMCACHED_HOST }}"
  PCA_MEMCACHED_0_PORT: "{{ settings.MEMCACHED_PORT }}"

  # Admin authentication
  PCA_ADMIN_USER: "{{ settings.ADMIN_USER }}"
  PCA_ADMIN_PASS: "{{ settings.ADMIN_PASS }}"

  # Disable metrics to avoid SQLite issues
  PCA_METRICS: "false"

volumes:
  - "{{ volume.data }}:/var/www/html/data"
  - "{{ instance.logs }}:/var/log/phpcacheadmin"

ports:
  - "{{ port.main }}:80"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=80"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
