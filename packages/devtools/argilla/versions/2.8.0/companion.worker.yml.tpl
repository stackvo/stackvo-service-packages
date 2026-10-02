image: "{{ companion.image }}"
container_name: "{{ companion.instance.container }}"
restart: unless-stopped

# The same image as the server, running the job queue's consumer instead:
# publishing a dataset and delivering webhooks are queued, not done in the request.
command:
  - "python"
  - "-m"
  - "argilla_server"
  - "worker"

environment:
  ARGILLA_DATABASE_URL: "postgresql+asyncpg://argilla:argilla@{{ companion.postgres.host }}:5432/argilla"
  ARGILLA_ELASTICSEARCH: "http://{{ companion.elasticsearch.host }}:9200"
  ARGILLA_REDIS_URL: "redis://{{ companion.redis.host }}:6379/0"

networks:
  {{ network }}:
    aliases: {{ companion.instance.aliases }}
