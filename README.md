# docker-swarm-keepalived

[![Build Workflow](https://github.com/lhns/docker-swarm-keepalived/workflows/build/badge.svg)](https://github.com/lhns/docker-swarm-keepalived/actions?query=workflow%3Abuild)
[![Docker Stars](https://img.shields.io/docker/stars/lolhens/keepalived-swarm)](https://hub.docker.com/r/lolhens/keepalived-swarm)
[![Docker Pulls](https://img.shields.io/docker/pulls/lolhens/keepalived-swarm)](https://hub.docker.com/r/lolhens/keepalived-swarm)
[![Docker Image Size](https://img.shields.io/docker/image-size/lolhens/keepalived-swarm)](https://hub.docker.com/r/lolhens/keepalived-swarm)
[![Apache License 2.0](https://img.shields.io/github/license/lhns/docker-swarm-keepalived.svg?maxAge=3600)](https://www.apache.org/licenses/LICENSE-2.0)

Operator for [keepalived](https://github.com/acassen/keepalived) on docker swarm.

Uses [osixia/docker-keepalived](https://github.com/osixia/docker-keepalived).

## Features

- **Operator Mode**: Run a single operator instance on master node to manage the entire cluster
- **Automatic Service Creation**: Automatically creates keepalived services for each manager node
- **Priority Management**: Automatically assigns priorities (leader gets highest priority)
- **Service Monitoring**: Continuous monitoring of keepalived services

## Usage

### Prerequisites

- Enable the "ip_vs" kernel module if not enabled
```sh
lsmod | grep -P '^ip_vs\s' || (echo "modprobe ip_vs" >> /etc/modules && modprobe ip_vs)
```

### Deploy using docker-compose

```sh
# Deploy using docker-compose
docker stack deploy -c services.yaml keepalived

# Or deploy using docker service create
docker service create \
  --name keepalived-operator \
  --constraint 'node.role==manager' \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --network host \
  --env KEEPALIVED_VIRTUAL_IPS="192.168.1.231,192.168.1.232" \
  ghcr.io/lhns/keepalived-swarm
```

## Docker Images

https://github.com/lhns/docker-swarm-keepalived/pkgs/container/keepalived-swarm

## Docker Stack Configuration

```yml
version: '3.8'

services:
  keepalived-operator:
    image: ghcr.io/lhns/keepalived-swarm
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - host
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
    environment:
      KEEPALIVED_VIRTUAL_IPS: "192.168.1.231, 192.168.1.232"
      KEEPALIVED_INTERFACE: "eth0"
      KEEPALIVED_PASSWORD: "8cteD88Hq4SZpPxm"
      KEEPALIVED_ROUTER_ID: "51"

networks:
  host:
    external: true
    name: host
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KEEPALIVED_IMAGE` | Keepalived image to use | `osixia/keepalived:2.0.20` |
| `KEEPALIVED_VIRTUAL_IPS` | Virtual IPs for keepalived | Required |
| `KEEPALIVED_INTERFACE` | Network interface | Auto-detected |
| `KEEPALIVED_PASSWORD` | VRRP password | `8cteD88Hq4SZpPxm` |
| `KEEPALIVED_ROUTER_ID` | VRRP router ID | `51` |
| `KEEPALIVED_NOTIFY` | Notification script | `/container/service/keepalived/assets/notify.sh` |
| `KEEPALIVED_COMMAND_LINE_ARGUMENTS` | Keepalived arguments | `--log-detail --dump-conf` |
| `KEEPALIVED_STATE` | Initial state | `BACKUP` |

## How It Works

1. **Single Instance**: Only one operator instance runs on the master node
2. **Service Discovery**: Discovers all manager nodes in the cluster
3. **Automatic Creation**: Creates keepalived services for each manager node
4. **Priority Assignment**: Automatically assigns priorities (leader: 200, others: decreasing)
5. **Monitoring**: Continuously monitors service health and status

## Testing Deployment

Use the provided test script to verify your deployment:

```sh
./test-deployment.sh
```

## Helpful Links

- https://github.com/acassen/keepalived
- https://github.com/osixia/docker-keepalived
- https://geek-cookbook.funkypenguin.co.nz/ha-docker-swarm/keepalived/

## License

This project uses the Apache 2.0 License. See the file called LICENSE.
