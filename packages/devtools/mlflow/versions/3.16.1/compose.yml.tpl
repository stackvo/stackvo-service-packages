image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# SQLite for runs and the registry, files for artifacts, both on one volume:
# the slim image ships no database driver, and a tracking server for local
# development gains nothing from a second container.
command:
  - "mlflow"
  - "server"
  - "--host=0.0.0.0"
  - "--port=5000"
  - "--backend-store-uri=sqlite:////mlflow/mlflow.db"
  - "--artifacts-destination=/mlflow/artifacts"
  - "--default-artifact-root=mlflow-artifacts:/"
  - "--serve-artifacts"
  - "--allowed-hosts={{ settings.ALLOWED_HOSTS }}"

volumes:
  - "{{ volume.data }}:/mlflow"

ports:
  - "{{ port.main }}:5000"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=5000"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
