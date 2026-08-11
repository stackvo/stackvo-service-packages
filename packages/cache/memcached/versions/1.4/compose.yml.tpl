image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

command: >
  memcached
  -m {{ settings.MEMORY }}
  -c {{ settings.CONNECTIONS }}
  -t {{ settings.THREADS }}
  {{ settings.EXTRA_ARGS }}

ports:
  - "{{ port.main }}:11211"

volumes:
  - "{{ instance.logs }}:/var/log/memcached"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
