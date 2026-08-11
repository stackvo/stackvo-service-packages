image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  MP_DATA_FILE: /data/mailpit.db

ports:
  - "{{ port.smtp }}:1025"
  - "{{ port.ui }}:8025"

volumes:
  - "{{ volume.data }}:/data"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
