image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  BLACKFIRE_SERVER_ID: "{{ settings.SERVER_ID }}"
  BLACKFIRE_SERVER_TOKEN: "{{ settings.SERVER_TOKEN }}"
  BLACKFIRE_LOG_LEVEL: "{{ settings.LOG_LEVEL }}"

ports:
  - "{{ port.main }}:8707"

volumes:
  - "{{ instance.logs }}:/var/log/blackfire"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
