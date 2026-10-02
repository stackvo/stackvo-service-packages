image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# One container, local mode: the Spark Connect server is the driver and runs the
# executors in-process. Clients attach with sc://<host>:15002 (PySpark, Scala);
# the web UI on 4040 shows their queries. The start script daemonises unless
# told not to, which would end the container at once.
command:
  - "/opt/spark/sbin/start-connect-server.sh"
  - "--master"
  - "{{ settings.MASTER }}"
  - "--driver-memory"
  - "{{ settings.DRIVER_MEMORY }}"
  - "--conf"
  - "spark.connect.grpc.binding.port=15002"
  - "--conf"
  - "spark.ui.port=4040"

environment:
  SPARK_NO_DAEMONIZE: "true"

volumes:
  - "{{ volume.data }}:/opt/spark/work-dir"

ports:
  - "{{ port.ui }}:4040"
  - "{{ port.connect }}:15002"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{{ instance.slug }}.rule=Host(`{{ instance.domain }}`)"
  - "traefik.http.routers.{{ instance.slug }}.entrypoints=websecure"
  - "traefik.http.routers.{{ instance.slug }}.tls=true"
  - "traefik.http.services.{{ instance.slug }}.loadbalancer.server.port=4040"
  - "traefik.http.middlewares.{{ instance.slug }}-revalidate.headers.customResponseHeaders.Cache-Control=no-cache"
  - "traefik.http.routers.{{ instance.slug }}.middlewares={{ instance.slug }}-revalidate"
