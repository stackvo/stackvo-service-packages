image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# Single-process development server (SQLite on the data volume). The Postgres
# based auto-setup image stopped at 1.29; the CLI image is what upstream ships
# for a local server now. The Web UI is the separate temporal-ui package.
command:
  - "server"
  - "start-dev"
  - "--headless"
  - "--ip"
  - "0.0.0.0"
  - "--port"
  - "7233"
  - "--http-port"
  - "7243"
  - "--db-filename"
  - "/home/temporal/temporal.db"
  - "--log-level"
  - "{{ settings.LOG_LEVEL }}"

volumes:
  - "{{ volume.data }}:/home/temporal"

ports:
  - "{{ port.main }}:7233"
  - "{{ port.http }}:7243"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
