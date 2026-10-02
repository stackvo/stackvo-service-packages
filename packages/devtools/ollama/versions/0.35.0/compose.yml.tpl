image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  OLLAMA_HOST: "0.0.0.0:11434"
  OLLAMA_KEEP_ALIVE: "{{ settings.KEEP_ALIVE }}"
  OLLAMA_MAX_LOADED_MODELS: "{{ settings.MAX_LOADED_MODELS }}"
  OLLAMA_NUM_PARALLEL: "{{ settings.NUM_PARALLEL }}"

volumes:
  - "{{ volume.models }}:/root/.ollama"

ports:
  - "{{ port.main }}:11434"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=11434"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
