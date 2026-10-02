image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# Self-contained on purpose: the registry keeps its artifacts in an embedded
# H2 file on the data volume, so it needs no Kafka and no external database.
# Apicurio's own Kafka and PostgreSQL storage kinds are for production sizing.
environment:
  APICURIO_STORAGE_KIND: "sql"
  APICURIO_STORAGE_SQL_KIND: "h2"
  APICURIO_DATASOURCE_URL: "jdbc:h2:file:/deployments/data/registry"

volumes:
  - "{{ volume.data }}:/deployments/data"

ports:
  - "{{ port.main }}:8080"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
