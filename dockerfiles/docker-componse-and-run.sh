#!/usr/bin/env sh

export SWARMPIT_URL_SRC="https://gist.githubusercontent.com/zeroc0d3/b09c6d8420d37176f246c4afe6ee4649/raw/529bd18a3e0fe1f0cba6720379df9e0959339a04/docker-compose.yml"
google-chrome http://play-with-docker.com/?stack=${SWARMPIT_URL_SRC}

### How to Deploy ###
# docker swarm init
# docker stack deploy -c docker-compose.yml swarmpit

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

version: '3.5'

services:
  app:
    image: swarmpit/swarmpit:latest
    environment:
      - VERSION=${DOCKER_VERSION:-19.03.2}
      - SWARMPIT_DB=http://db:5984
      - SWARMPIT_INFLUXDB=http://influxdb:8086
      - INTERACTIVE=0
      - ADMIN_USERNAME=admin
      - ADMIN_PASSWORD=password
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - 3101:8080
    networks:
      - net
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 1024M
        reservations:
          cpus: '0.25'
          memory: 512M
      placement:
        constraints:
          - node.role == manager

  db:
    image: couchdb:2.3.0
    volumes:
      - db-data:/opt/couchdb/data
    networks:
      - net
    deploy:
      resources:
        limits:
          cpus: '0.30'
          memory: 256M
        reservations:
          cpus: '0.15'
          memory: 128M

  influxdb:
    image: influxdb:1.7
    volumes:
      - influx-data:/var/lib/influxdb
    networks:
      - net
    deploy:
      resources:
        limits:
          cpus: '0.30'
          memory: 256M
        reservations:
          cpus: '0.15'
          memory: 128M

  agent:
    image: swarmpit/agent:latest
    environment:
      - DOCKER_API_VERSION=1.35
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - net
    deploy:
      mode: global
      labels:
        swarmpit.agent: 'true'
      resources:
        limits:
          cpus: '0.10'
          memory: 64M
        reservations:
          cpus: '0.05'
          memory: 32M

networks:
  net:
    driver: overlay
    attachable: true

volumes:
  db-data:
    driver: local
  influx-data:
    driver: local
