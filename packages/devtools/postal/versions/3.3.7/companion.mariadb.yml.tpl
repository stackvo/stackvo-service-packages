image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

environment:
  # Reachable only from the workspace network and published on no host port,
  # so there is no credential to protect; Postal connects as root.
  MARIADB_ALLOW_EMPTY_ROOT_PASSWORD: "1"

command: >
  mariadbd
  --character-set-server=utf8mb4
  --collation-server=utf8mb4_unicode_ci

volumes:
  - "{{ companion.volume.data }}:/var/lib/mysql"

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
