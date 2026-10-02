image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command:
  - "run"
  - "/connect.yaml"

volumes:
  - "{{ file.connect_yaml }}:/connect.yaml:ro"

ports:
  - "{{ port.main }}:4195"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
