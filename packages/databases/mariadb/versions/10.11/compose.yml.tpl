image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  MARIADB_ROOT_PASSWORD: "{{ settings.ROOT_PASSWORD }}"
  MARIADB_DATABASE: "{{ settings.DATABASE }}"

volumes:
  - "{{ volume.data }}:/var/lib/mysql"
  - "{{ file.mariadb_cnf }}:/etc/mysql/conf.d/stackvo.cnf:ro"
  # Log volume mount removed - logs go to stdout/stderr (GEMINI.md compliance)

command: >
  mariadbd
  --character-set-server=utf8mb4
  --collation-server=utf8mb4_unicode_ci

ports:
  - "{{ port.main }}:3306"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
