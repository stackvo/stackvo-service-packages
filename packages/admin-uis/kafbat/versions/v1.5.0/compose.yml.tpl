image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  DYNAMIC_CONFIG_ENABLED: "{{ settings.DYNAMIC_CONFIG }}"
  KAFKA_CLUSTERS_0_NAME: "{{ settings.CLUSTER_NAME }}"
  KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: "{{ settings.BOOTSTRAP_SERVERS }}"

volumes:
  - "{{ instance.logs }}:/var/log/kafbat"

ports:
  - "{{ port.main }}:8080"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=8080"
