#!/bin/sh

# Konfigürasyon dosyasının varlığını kontrol et
if [ ! -f /etc/graylog/server/server.conf ]; then
  echo "Configuration file /etc/graylog/server/server.conf does not exist!"
  exit 1
fi

# Graylog'u başlat
/docker-entrypoint.sh &

# # Wait for Graylog to be fully up and running
echo "Waiting for Graylog to start..."
until curl -s -u admin:yourpassword -X GET 'http://localhost:9000/api/system/inputs' > /dev/null; do
  echo "Graylog not yet ready, waiting 5 seconds..."
  sleep 5
done
echo "Waiting for Graylog to started."

# # Setup GELF UDP input
echo "Setting up Graylog GELF UDP input..."
curl -u admin:yourpassword -X POST "http://localhost:9000/api/system/inputs" -H "Content-Type: application/json" -H "X-Requested-By: setup_script" -d '{
  "title": "GELF UDP",
  "type": "org.graylog2.inputs.gelf.udp.GELFUDPInput",
  "configuration": {
    "bind_address": "0.0.0.0",
    "port": 12201,
    "recv_buffer_size": 262144,
    "decompress_size_limit": 8388608
  },
  "global": true
}'
echo "Setting up Graylog GELF UDP input added."

# Graylog'un foreground modda çalışmasını sağla
# wait -n
sleep infinity