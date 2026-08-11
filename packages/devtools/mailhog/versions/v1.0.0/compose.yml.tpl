image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

ports:
  - "{{ port.smtp }}:1025"
  - "{{ port.ui }}:8025"

volumes:
  - "{{ instance.logs }}:/var/log/mailhog"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
