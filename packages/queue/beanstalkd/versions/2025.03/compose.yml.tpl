image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

volumes:
  - "{{ volume.data }}:/data"

command: >
  -l 0.0.0.0
  -p 11300
  -b /data
  -z {{ settings.MAX_JOB_SIZE }}

ports:
  - "{{ port.main }}:11300"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
