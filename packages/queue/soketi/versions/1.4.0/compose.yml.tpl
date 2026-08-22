image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  SOKETI_DEBUG: "{{ settings.DEBUG }}"
  SOKETI_METRICS_ENABLED: "{{ settings.METRICS_ENABLED }}"
  SOKETI_DEFAULT_APP_ID: "{{ settings.DEFAULT_APP_ID }}"
  SOKETI_DEFAULT_APP_KEY: "{{ settings.DEFAULT_APP_KEY }}"
  SOKETI_DEFAULT_APP_SECRET: "{{ settings.DEFAULT_APP_SECRET }}"
  SOKETI_DEFAULT_APP_ENABLE_CLIENT_MESSAGES: "{{ settings.ENABLE_CLIENT_MESSAGES }}"

ports:
  - "{{ port.main }}:6001"
  - "{{ port.metrics }}:9601"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
