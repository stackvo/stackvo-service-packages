image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
