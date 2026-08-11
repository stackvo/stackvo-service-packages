image: "{{ image }}"
container_name: "{{ instance.container }}"
restart: unless-stopped

# Single-node replica set, not standalone. Change streams (db.watch()) and
# retryable writes need an oplog, which only a replica set has; a standalone
# mongod rejects $changeStream with "only supported on replica sets".
#
# --replSet together with --auth forces internal cluster auth, so mongod
# refuses to boot without a keyFile ("security.keyFile is required when
# authorization is enabled with replica sets"). The keyFile is generated on
# first boot inside the data volume, so it survives restarts and never has to
# be bind-mounted from the host (a host bind mount would carry the host's uid
# and mode, and mongod rejects a keyFile it does not own or that is group/world
# readable).
#
# The member is registered as "stackvo-mongo:27017" so other containers can
# follow replica-set discovery. A client on the HOST talking to 127.0.0.1:27017
# discovers that name, cannot resolve it, and hangs — host tools (Compass,
# TablePlus) must append "directConnection=true" to the connection string.
command:
  - "bash"
  - "-c"
  - |
    if [ ! -s /data/db/.keyfile ]; then openssl rand -base64 756 > /data/db/.keyfile; fi
    chmod 400 /data/db/.keyfile
    chown mongodb:mongodb /data/db/.keyfile
    (
      until mongosh --quiet -u "{{ settings.INITDB_ROOT_USERNAME }}" -p "{{ settings.INITDB_ROOT_PASSWORD }}" --authenticationDatabase admin --eval "db.adminCommand({ping:1})" >/dev/null 2>&1; do sleep 1; done
      mongosh --quiet -u "{{ settings.INITDB_ROOT_USERNAME }}" -p "{{ settings.INITDB_ROOT_PASSWORD }}" --authenticationDatabase admin --eval "try { rs.status() } catch (e) { rs.initiate({_id: \"{{ settings.REPLSET }}\", members: [{_id: 0, host: \"stackvo-mongo:27017\"}]}) }" >/dev/null 2>&1
    ) &
    exec docker-entrypoint.sh mongod --auth --bind_ip_all --replSet {{ settings.REPLSET }} --keyFile /data/db/.keyfile

environment:
  MONGO_INITDB_ROOT_USERNAME: "{{ settings.INITDB_ROOT_USERNAME }}"
  MONGO_INITDB_ROOT_PASSWORD: "{{ settings.INITDB_ROOT_PASSWORD }}"
  MONGO_INITDB_DATABASE: "{{ settings.DATABASE }}"

volumes:
  - "{{ volume.data }}:/data/db"
  - "{{ file.mongo_conf }}:/etc/mongo/mongo.conf:ro"
  - "{{ instance.logs }}:/var/log/mongodb"

ports:
  - "{{ port.main }}:27017"

networks:
  {{ network }}:
    aliases: {{ instance.aliases }}
