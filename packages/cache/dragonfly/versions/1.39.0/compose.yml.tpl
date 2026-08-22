image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# `--requirepass=` with an empty value is what Dragonfly itself defaults to, so
# a workspace that never set a password gets the same open instance the Redis
# package ships rather than one that refuses every command.
command:
  - "dragonfly"
  - "--logtostderr"
  - "--dir=/data"
  - "--dbfilename=dump"
  - "--requirepass={{ settings.PASSWORD }}"

# Dragonfly locks its memory. Without this the container starts and then fails
# the first allocation it cannot pin, which reads as a crash with no message.
ulimits:
  memlock: -1

volumes:
  - "{{ volume.data }}:/data"

ports:
  - "{{ port.main }}:6379"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
