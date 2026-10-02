image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

environment:
  POSTGRES_DB: "argilla"
  POSTGRES_USER: "argilla"
  POSTGRES_PASSWORD: "argilla"

volumes:
  - "{{ companion.volume.data }}:/var/lib/postgresql/data"

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
