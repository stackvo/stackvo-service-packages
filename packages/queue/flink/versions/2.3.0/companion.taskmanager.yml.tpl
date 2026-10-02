image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

command: taskmanager

environment:
  FLINK_PROPERTIES: |
    jobmanager.rpc.address: {{ instance.container }}
    taskmanager.bind-host: 0.0.0.0
    taskmanager.numberOfTaskSlots: 2

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
