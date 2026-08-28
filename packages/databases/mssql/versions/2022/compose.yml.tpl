image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

environment:
  ACCEPT_EULA: "{{ settings.ACCEPT_EULA }}"
  MSSQL_SA_PASSWORD: "{{ settings.SA_PASSWORD }}"
  MSSQL_PID: "{{ settings.EDITION }}"

volumes:
  - "{{ volume.data }}:/var/opt/mssql"

ports:
  - "{{ port.main }}:1433"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
