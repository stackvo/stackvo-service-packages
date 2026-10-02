image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command:
  - "-config.file=/etc/loki/loki.yaml"

volumes:
  - "{{ volume.data }}:/loki"
  - "{{ file.loki_yaml }}:/etc/loki/loki.yaml:ro"

ports:
  - "{{ port.main }}:3100"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
