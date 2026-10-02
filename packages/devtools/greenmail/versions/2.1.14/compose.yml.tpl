image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  # Every protocol on its test port (SMTP 3025, POP3 3110, IMAP 3143 and the
  # TLS variants), bound to all interfaces so the host and the workspace
  # network can both reach it. With auth disabled a mailbox is created the
  # first time anybody delivers to it or logs in, so no user list is needed.
  GREENMAIL_OPTS: "-Dgreenmail.setup.test.all -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.auth.disabled"

ports:
  - "{{ port.smtp }}:3025"
  - "{{ port.imap }}:3143"
  - "{{ port.pop3 }}:3110"
  - "{{ port.api }}:8080"

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
