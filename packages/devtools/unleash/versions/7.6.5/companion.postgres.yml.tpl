image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

# Reachable only from the workspace network and used by this instance alone,
# so its credentials are fixed here rather than offered as settings.
environment:
  POSTGRES_DB: "unleash"
  POSTGRES_USER: "unleash"
  POSTGRES_PASSWORD: "unleash"

volumes:
  - "{{ companion.volume.data }}:/var/lib/postgresql/data"

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
