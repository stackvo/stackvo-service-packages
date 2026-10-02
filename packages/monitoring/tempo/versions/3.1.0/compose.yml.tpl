image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command:
  - "-target=all"
  - "-config.file=/etc/tempo/tempo.yaml"

volumes:
  - "{{ volume.data }}:/var/tempo"
  - "{{ file.tempo_yaml }}:/etc/tempo/tempo.yaml:ro"

ports:
  - "{{ port.main }}:3200"
  - "{{ port.otlp-grpc }}:4317"
  - "{{ port.otlp-http }}:4318"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
