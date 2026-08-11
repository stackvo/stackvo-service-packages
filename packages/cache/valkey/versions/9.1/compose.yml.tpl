image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command: ["valkey-server", "/etc/valkey/valkey.conf"]

volumes:
  - "{{ volume.data }}:/data"
  - "{{ file.valkey_conf }}:/etc/valkey/valkey.conf:ro"

ports:
  - "{{ port.main }}:6379"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
