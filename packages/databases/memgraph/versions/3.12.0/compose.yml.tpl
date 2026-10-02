image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

volumes:
  - "{{ volume.data }}:/var/lib/memgraph"

ports:
  - "{{ port.bolt }}:7687"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
