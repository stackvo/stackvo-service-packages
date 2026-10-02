image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command:
  - "--config=/etc/otelcol-contrib/config.yaml"

volumes:
  - "{{ file.config_yaml }}:/etc/otelcol-contrib/config.yaml:ro"

ports:
  - "{{ port.grpc }}:4317"
  - "{{ port.http }}:4318"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
