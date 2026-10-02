image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped
init: true

environment:
  # Postal 3 reads its whole configuration from the environment, so no
  # postal.yml is shipped. The config directory only holds the two keys the
  # wrapper below generates on first boot.
  POSTAL_CONFIG_FILE_PATH: /opt/postal/config/postal.yml
  POSTAL_SIGNING_KEY_PATH: /opt/postal/config/signing.key
  POSTAL_WEB_HOSTNAME: "postal.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  POSTAL_WEB_PROTOCOL: https
  POSTAL_SMTP_HOSTNAME: "postal.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  WEB_SERVER_DEFAULT_BIND_ADDRESS: "0.0.0.0"
  SMTP_SERVER_DEFAULT_PORT: "25"
  # The metadata and per-server message databases live in the companion
  # MariaDB, which is reachable only from the workspace network.
  MAIN_DB_HOST: "{{ companion.mariadb.host }}"
  MAIN_DB_USERNAME: root
  MAIN_DB_PASSWORD: ""
  MAIN_DB_DATABASE: postal
  MESSAGE_DB_HOST: "{{ companion.mariadb.host }}"
  MESSAGE_DB_USERNAME: root
  MESSAGE_DB_PASSWORD: ""
  MESSAGE_DB_DATABASE_NAME_PREFIX: postal
  DNS_MX_RECORDS: '["mx.postal.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"]'
  DNS_SPF_INCLUDE: "spf.postal.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  DNS_RETURN_PATH_DOMAIN: "rp.postal.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  DNS_ROUTE_DOMAIN: "routes.postal.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  DNS_TRACK_DOMAIN: "track.postal.stackvo.{{ settings.DEFAULT_TLD_SUFFIX }}"
  POSTAL_ADMIN_EMAIL: "{{ settings.ADMIN_EMAIL }}"
  POSTAL_ADMIN_PASSWORD: "{{ settings.ADMIN_PASSWORD }}"

# One image runs three processes — web, SMTP and worker — and `postal
# initialize` has to finish before any of them starts. This wrapper does the
# first-boot steps (signing key, session key, schema, first admin) and then
# supervises the three: if any one exits the container exits and restarts.
command:
  - "bash"
  - "-c"
  - |
    set -e
    [ -f /opt/postal/config/signing.key ] || openssl genrsa -out /opt/postal/config/signing.key 2048
    [ -f /opt/postal/config/secret.key ] || openssl rand -hex 64 > /opt/postal/config/secret.key
    export RAILS_SECRET_KEY=`cat /opt/postal/config/secret.key`
    until postal initialize; do echo "waiting for the database"; sleep 3; done
    (cd /opt/postal/app && bundle exec rails runner "User.count.zero? && User.create!(email_address: ENV['POSTAL_ADMIN_EMAIL'], password: ENV['POSTAL_ADMIN_PASSWORD'], first_name: 'Postal', last_name: 'Admin', admin: true, email_verified_at: Time.now)") || true
    trap "kill 0" TERM INT
    postal web-server &
    postal worker &
    postal smtp-server &
    wait -n
    exit 1

volumes:
  - "{{ volume.config }}:/opt/postal/config"

ports:
  - "{{ port.web }}:5000"
  - "{{ port.smtp }}:25"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=5000"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
