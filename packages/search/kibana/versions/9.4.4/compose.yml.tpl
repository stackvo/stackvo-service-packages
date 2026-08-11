image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  ELASTICSEARCH_HOSTS: "{{ settings.ELASTICSEARCH_HOSTS }}"
  SERVER_NAME: "{{ settings.SERVER_NAME }}"
  SERVER_HOST: "{{ settings.SERVER_HOST }}"

volumes:
  - "{{ volume.data }}:/usr/share/kibana/data"
  - "{{ instance.logs }}:/usr/share/kibana/logs"

ports:
  - "{{ port.main }}:5601"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
