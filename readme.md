# Graylog Logging Setup with Docker

This repository contains a complete setup for a logging system using Graylog, Elasticsearch, Logstash, and MongoDB via Docker Compose. This setup allows you to centralize and manage your logs efficiently.

## Table of Contents

- [Graylog Logging Setup with Docker](#graylog-logging-setup-with-docker)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Getting Started](#getting-started)
    - [Clone the Repository](#clone-the-repository)
    - [Build and Run the Containers](#build-and-run-the-containers)
  - [Usage](#usage)
    - [Sending Logs](#sending-logs)
  - [Configuration](#configuration)
    - [Logstash Configuration](#logstash-configuration)
    - [Graylog Configuration](#graylog-configuration)
    - [Example Docker Compose](#example-docker-compose)
  - [Troubleshooting](#troubleshooting)
  - [References](#references)

## Overview

Graylog is a powerful open-source log management platform that provides real-time search and analysis. Combined with Elasticsearch and MongoDB, this setup ensures efficient storage and retrieval of log data.

## Features

- Centralized log management
- Real-time search and analysis
- Scalable architecture using Docker
- Secure communication with Elasticsearch
- Automatic input configuration for Graylog

## Prerequisites

- Docker
- Docker Compose
- A suitable environment to run Docker containers

## Getting Started

### Clone the Repository

```sh
git clone https://github.com/TurkNet/graylog-example.git
cd graylog-setup
```

### Build and Run the Containers

```sh
docker-compose up -d
```

## Usage

### Sending Logs

You can send logs to Logstash, which then forwards them to Graylog. Here's an example using `curl`:

```sh
curl -X POST "http://localhost:5601" -H "Content-Type: application/json" -d '{
  "message": "2024-07-30T11:14:43.511Z [main]>worker0 INFO com.example.MainClass - This is a test log message",
  "timestamp": "2024-07-30T11:14:43.511Z",
  "level": "INFO",
  "application": "test_app",
  "host": "localhost"
}'
```

## Configuration

### Logstash Configuration

The `logstash.conf` file used in this setup:

```sh
input {
  http {
    port => 5601
  }
}

filter {
  grok {
    match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} \[%{DATA:thread}\]>%{DATA:worker} %{LOGLEVEL:loglevel} %{DATA:class} - %{GREEDYDATA:log_message}" }
  }
  mutate {
    remove_field => ["headers"]
  }
}

output {
  gelf {
    host => "graylog"
    port => 12201
    protocol => "UDP"
    codec => "json"
  }
  stdout{
    codec=>rubydebug
  }
}
```

### Graylog Configuration

The `setup_graylog_inputs.sh` script ensures Graylog is configured to receive logs via GELF UDP:

```sh
#!/bin/sh

# Konfigürasyon dosyasının varlığını kontrol et
if [ ! -f /etc/graylog/server/server.conf ]; then
  echo "Configuration file /etc/graylog/server/server.conf does not exist!"
  exit 1
fi

# Graylog'u başlat
/docker-entrypoint.sh &

# Wait for Graylog to be fully up and running
echo "Waiting for Graylog to start..."
until curl -s -u admin:yourpassword -X GET 'http://localhost:9000/api/system/inputs' > /dev/null; do
  echo "Graylog not yet ready, waiting 5 seconds..."
  sleep 5
done
echo "Waiting for Graylog to started."

# Setup GELF UDP input
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
sleep infinity
```

### Example Docker Compose

```yaml
version: '3.8'

services:
  # MongoDB, Graylog'un bir bileşenidir
  mongo:
    image: arm64v8/mongo:6.0.16-jammy
    container_name: mongo
    networks:
      - graylog
    volumes:
      - mongo_data:/data/db

  # ElasticSearch, Graylog'un bir bileşenidir
  elasticsearch:
    image: elasticsearch:7.10.1
    container_name: elasticsearch
    environment:
      - http.host=0.0.0.0
      - transport.host=127.0.0.1
      - network.host=0.0.0.0
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - cluster.name=graylog
      - node.name=graylog
      - "discovery.type=single-node"
      - "ELASTIC_PASSWORD=your_elastic_password"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    mem_limit: 1g
    ports:
      - 9200:9200
    networks:
      - graylog
    # volumes:
    #   - es_data:/usr/share/elasticsearch/data

  # Graylog, log yönetim ve analiz sistemi
  graylog:
    image: graylog/graylog:6.0.4-1
    container_name: graylog
    user: root
    environment:
      # UI admin pass yourpassword
      - GRAYLOG_HTTP_BIND_ADDRESS=0.0.0.0:9000
      - GRAYLOG_PASSWORD_SECRET=somepasswordpepper
      - GRAYLOG_ROOT_PASSWORD_SHA2=e3c652f0ba0b4801205814f8b6bc49672c4c74e25b497770bb89b22cdeb4e951
      - GRAYLOG_HTTP_EXTERNAL_URI=http://localhost:9000/
      - GRAYLOG_MONGODB_URI=mongodb://mongo:27017/graylog
      - GRAYLOG_ELASTICSEARCH_HOSTS=http://elastic:your_elastic_password@elasticsearch:9200
    volumes:
      - graylog_data:/usr/share/graylog/data
      - ./graylog/setup_graylog_inputs.sh:/etc/graylog/setup_graylog_inputs.sh
      # - ./graylog/server.conf:/etc/graylog/server/server.conf
      - ./graylog/graylog.conf:/etc/graylog/server/server.conf
    depends_on:
      - mongo
      - elasticsearch
    networks:
      - graylog
    ports:
      - "9000:9000"
      - "12201:12201/udp"
    entrypoint: /etc/graylog/setup_graylog_inputs.sh

  # Logstash, logları toplamak ve Graylog'a göndermek için
  logstash:
    build:
      context: ./logstash
    container_name: logstash
    volumes:
      - ./logstash/config:/usr/share/logstash/config
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    links:
      - graylog
    depends_on:
      - graylog
    ports:
      - "5601:5601"
    networks:
      - graylog

networks:
  graylog:
    driver: bridge

volumes:
  mongo_data:
    driver: local
  es_data:
    driver: local
  graylog_data:
```

## Troubleshooting

- **Common Errors**:
  - Ensure all services are running using `docker-compose ps`.
  - Check logs for errors using `docker logs <container_name>`.
  - Verify certificates and keys are correctly generated and placed.

- **Useful Commands**:
  - Restart services: `docker-compose restart`.
  - View logs: `docker logs -f <container_name>`.
  - Access Graylog: `http://localhost:9000`.

## References

- [Graylog Documentation](https://docs.graylog.org/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Docker Documentation](https://docs.docker.com/)

---

This `README.md` provides a comprehensive guide for setting up and using your Graylog application, ensuring that new users can easily understand and get started with your logging system.