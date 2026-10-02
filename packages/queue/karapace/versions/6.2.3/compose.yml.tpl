image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

entrypoint:
  - python3
  - -m
  - karapace

environment:
  KARAPACE_KARAPACE_REGISTRY: "true"
  KARAPACE_HOST: "0.0.0.0"
  KARAPACE_PORT: "8081"
  KARAPACE_ADVERTISED_HOSTNAME: "{{ instance.container }}"
  KARAPACE_BOOTSTRAP_URI: "{{ settings.BOOTSTRAP_SERVERS }}"
  KARAPACE_CLIENT_ID: "{{ instance.slug }}"
  KARAPACE_GROUP_ID: "{{ instance.slug }}"
  KARAPACE_MASTER_ELIGIBILITY: "true"
  KARAPACE_TOPIC_NAME: "{{ settings.TOPIC_NAME }}"
  KARAPACE_COMPATIBILITY: "{{ settings.COMPATIBILITY }}"
  KARAPACE_LOG_LEVEL: "INFO"

ports:
  - "{{ port.main }}:8081"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
