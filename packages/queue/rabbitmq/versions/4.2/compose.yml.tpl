image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  RABBITMQ_DEFAULT_USER: "{{ settings.DEFAULT_USER }}"
  RABBITMQ_DEFAULT_PASS: "{{ settings.DEFAULT_PASS }}"
  RABBITMQ_DEFAULT_VHOST: "/"

volumes:
  - "{{ volume.data }}:/var/lib/rabbitmq"
  - "{{ volume.logs }}:/var/log/rabbitmq"

ports:
  - "{{ port.main }}:5672"
  - "{{ port.mgmt }}:15672"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
