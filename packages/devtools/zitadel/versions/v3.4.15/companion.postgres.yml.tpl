image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

# Reachable only from the workspace network and used by this instance alone,
# so its credentials are fixed here rather than offered as settings.
environment:
  POSTGRES_DB: "zitadel"
  POSTGRES_USER: "zitadel"
  POSTGRES_PASSWORD: "zitadel"

volumes:
  - "{{ companion.volume.data }}:/var/lib/postgresql/data"

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
