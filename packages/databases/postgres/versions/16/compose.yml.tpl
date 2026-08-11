image: "{{ image }}"
container_name: "{{ instance.container }}"
command: postgres -c config_file=/etc/postgresql/postgresql.conf
restart: unless-stopped

environment:
  POSTGRES_DB: "{{ settings.DB }}"
  POSTGRES_USER: "{{ settings.USER }}"
  POSTGRES_PASSWORD: "{{ settings.PASSWORD }}"
  PGDATA: "/var/lib/postgresql/data/pgdata"

volumes:
  - "{{ volume.data }}:/var/lib/postgresql/data/pgdata"
  - "{{ instance.logs }}:/var/log/postgresql"
  - "{{ file.postgres_conf }}:/etc/postgresql/postgresql.conf:ro"

ports:
  - "{{ port.main }}:5432"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
