# Docker Swarm Keepalived Operator

A smart operator for managing [Keepalived](https://github.com/acassen/keepalived) services across Docker Swarm clusters with automatic node discovery and dynamic service management.

## 🚀 Quick Start

### 1. Label Your Nodes
```bash
# Label nodes where keepalived should run
docker node update node1 --label-add keepalived_group=production
docker node update node2 --label-add keepalived_group=production
docker node update node3 --label-add keepalived_group=production
```

### 2. Deploy the Operator
```bash
docker service create \
  --name keepalived-operator \
  --constraint 'node.role==manager' \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --network host \
  --env KEEPALIVED_GROUP=production \
  --env KEEPALIVED_VIRTUAL_IPS="192.168.1.201,192.168.1.202" \
  --env KEEPALIVED_INTERFACE=eth0 \
  pubimgs/keepalived-swarm-operator:latest
```

## ✨ Key Features

- **🎯 Auto Node Discovery** - Finds nodes with `keepalived_group` labels
- **⚡ Dynamic Management** - Creates/deletes services based on label changes
- **⚖️ Priority Control** - Custom VRRP priorities via node labels
- **📊 Health Monitoring** - 24/7 service monitoring
- **🏷️ Multi-Environment** - Support for production, staging, etc.
- **🔧 Auto Config** - Generates UNICAST_PEERS automatically

## 📋 Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `KEEPALIVED_GROUP` | ✅ | Node group to target | - |
| `KEEPALIVED_VIRTUAL_IPS` | ✅ | Virtual IPs (comma-separated) | - |
| `KEEPALIVED_INTERFACE` | ❌ | Network interface | Auto-detected |
| `KEEPALIVED_PASSWORD` | ❌ | VRRP password | - |
| `KEEPALIVED_ROUTER_ID` | ❌ | VRRP router ID | `51` |
| `KEEPALIVED_IMAGE` | ❌ | Keepalived image | `osixia/keepalived:2.0.20` |

## 🏗️ Docker Stack Example

```yaml
version: '3.8'
services:
  keepalived_operator:
    image: pubimgs/keepalived-swarm-operator:latest
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
      KEEPALIVED_GROUP: "production"
      KEEPALIVED_VIRTUAL_IPS: "192.168.1.201,192.168.1.202"
      KEEPALIVED_INTERFACE: "eth0"
      KEEPALIVED_PASSWORD: "your_secure_password"

networks:
  host:
    external: true
    name: host
```

## 🔄 How It Works

1. **Operator runs on Manager node** - Single instance manages the cluster
2. **Discovers labeled nodes** - Finds nodes with `keepalived_group` labels
3. **Creates keepalived services** - One service per matching node
4. **Monitors continuously** - Checks every 10 seconds for changes
5. **Auto-manages lifecycle** - Creates/deletes services as labels change

## 🎯 Node Priority Management

```bash
# Set custom priorities (higher = more preferred)
docker node update node1 --label-add KEEPALIVED_PRIORITY=100
docker node update node2 --label-add KEEPALIVED_PRIORITY=101
docker node update node3 --label-add KEEPALIVED_PRIORITY=102
```

## 📊 Monitoring

```bash
# View operator logs
docker service logs -f keepalived-operator

# Check keepalived services
docker service ls --filter name=keepalived-node

# Test virtual IP
ping -c 3 192.168.1.201
```

## 🛠️ Prerequisites

- Docker Swarm cluster
- Manager node access
- `ip_vs` kernel module enabled:
```bash
modprobe ip_vs
echo "ip_vs" >> /etc/modules
```

## 📚 Links

- **GitHub**: https://github.com/isqiao/keepalived-docker-swarm-operator
- **Documentation**: Full README with examples and troubleshooting
- **Issues**: Report bugs and request features
- **Original Project**: https://github.com/lhns/docker-swarm-keepalived

## 📄 License

Apache 2.0 License

---

⭐ **Star the project if it helps you!** ⭐