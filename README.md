# Keepalived Docker Swarm Operator

[![Build Workflow](https://github.com/isqiao/keepalived-docker-swarm-operator/workflows/build/badge.svg)](https://github.com/isqiao/keepalived-docker-swarm-operator/actions?query=workflow%3Abuild)
[![Docker Stars](https://img.shields.io/docker/stars/pubimgs/keepalived-swarm-operator)](https://hub.docker.com/r/pubimgs/keepalived-swarm-operator)
[![Docker Pulls](https://img.shields.io/docker/pulls/pubimgs/keepalived-swarm-operator)](https://hub.docker.com/r/pubimgs/keepalived-swarm-operator)
[![Docker Image Size](https://img.shields.io/docker/image-size/pubimgs/keepalived-swarm-operator)](https://hub.docker.com/r/pubimgs/keepalived-swarm-operator)
[![Apache License 2.0](https://img.shields.io/github/license/isqiao/keepalived-docker-swarm-operator.svg?maxAge=3600)](https://www.apache.org/licenses/LICENSE-2.0)

A smart [Keepalived](https://github.com/acassen/keepalived) operator designed specifically for Docker Swarm, providing high-availability virtual IP management solution.

Built on top of [osixia/docker-keepalived](https://github.com/osixia/docker-keepalived).

## 🏗️ Architecture

This project follows the operator pattern with two core components:

### 1. Keepalived Operator (This Container)
- **Deployment**: Must run on Manager nodes
- **Core Features**:
  - Auto-discovers nodes with `keepalived_group` labels
  - Dynamically creates and manages keepalived services across the cluster
  - Real-time service health monitoring
  - Handles node label changes and service synchronization

### 2. Keepalived Service Instances
- **Deployment**: Can run on any node (Manager or Worker)
- **Core Features**:
  - Provides actual VRRP protocol functionality
  - Only deployed on nodes matching `keepalived_group` labels
  - Handles virtual IP failover

## ✨ Key Features

- **🎯 Smart Node Discovery**: Automatically identifies and manages nodes with specific labels
- **🔄 Dynamic Service Management**: Real-time response to node label changes, auto-create/delete services
- **⚖️ Flexible Priority Configuration**: Support custom VRRP priorities via node labels
- **📊 Continuous Health Monitoring**: 24/7 keepalived service status monitoring
- **🏷️ Group Management**: Support multi-environment deployments (production, staging, etc.)
- **🔧 Auto Configuration**: Automatically generates UNICAST_PEERS and formats configurations

## 🚀 Quick Start

### Prerequisites

Ensure the `ip_vs` kernel module is enabled:

```bash
# Check module status
lsmod | grep -P '^ip_vs\s'

# If not enabled, run the following
echo "modprobe ip_vs" >> /etc/modules && modprobe ip_vs
```

### Node Labeling

Before deployment, label the nodes where you want to run keepalived services:

```bash
# Label nodes for production environment
docker node update node1 --label-add keepalived_group=production
docker node update node2 --label-add keepalived_group=production
docker node update node3 --label-add keepalived_group=production

# Optional: Set custom priorities (higher values = higher priority)
docker node update node1 --label-add KEEPALIVED_PRIORITY=100
docker node update node2 --label-add KEEPALIVED_PRIORITY=101
docker node update node3 --label-add KEEPALIVED_PRIORITY=102

# Support multi-environment deployments
docker node update test-node1 --label-add keepalived_group=staging
docker node update test-node2 --label-add keepalived_group=staging

# Remove node labels (auto-cleanup corresponding services)
docker node update node1 --label-rm keepalived_group
```

### Deployment Options

#### Option 1: Using Docker Stack (Recommended)

```bash
# Deploy using the provided services.yaml
docker stack deploy -c services.yaml keepalived-stack
```

#### Option 2: Using Docker Service

```bash
docker service create \
  --name keepalived-operator \
  --constraint 'node.role==manager' \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --network host \
  --env KEEPALIVED_GROUP=production \
  --env KEEPALIVED_VIRTUAL_IPS="192.168.1.201,192.168.1.202" \
  --env KEEPALIVED_INTERFACE=eth0 \
  --env KEEPALIVED_PASSWORD=your_secure_password \
  ghcr.io/isqiao/keepalived-swarm-operator:latest
```

## 📦 Docker Images

- **GitHub Container Registry**: `ghcr.io/isqiao/keepalived-swarm-operator`
- **Latest Version**: `ghcr.io/isqiao/keepalived-swarm-operator:latest`

## 📋 Configuration Examples

### Docker Stack Configuration

```yaml
version: '3.8'

services:
  keepalived_operator:
    image: ghcr.io/isqiao/keepalived-swarm-operator:latest
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
      # Required parameters
      KEEPALIVED_GROUP: "production"                     # Node group name
      KEEPALIVED_VIRTUAL_IPS: "192.168.1.201,192.168.1.202"  # Virtual IP list

      # Optional parameters
      KEEPALIVED_INTERFACE: "eth0"                       # Network interface
      KEEPALIVED_PASSWORD: "your_secure_password"        # VRRP password
      KEEPALIVED_ROUTER_ID: "51"                         # Router ID
      KEEPALIVED_IMAGE: "osixia/keepalived:2.0.20"      # Keepalived image

networks:
  host:
    external: true
    name: host
```

## ⚙️ Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `KEEPALIVED_GROUP` | Node label group name for filtering target nodes | `""` | **Yes** |
| `KEEPALIVED_VIRTUAL_IPS` | Virtual IP address list (comma-separated) | `""` | **Yes** |
| `KEEPALIVED_IMAGE` | Keepalived Docker image to use | `osixia/keepalived:2.0.20` | No |
| `KEEPALIVED_INTERFACE` | Network interface name | Auto-detected | No |
| `KEEPALIVED_PASSWORD` | VRRP authentication password | `""` | No |
| `KEEPALIVED_ROUTER_ID` | VRRP router ID | `51` | No |
| `KEEPALIVED_NOTIFY` | State change notification script path | `/container/service/keepalived/assets/notify.sh` | No |
| `KEEPALIVED_COMMAND_LINE_ARGUMENTS` | Keepalived startup arguments | `--log-detail --dump-conf` | No |
| `KEEPALIVED_STATE` | Initial state | `BACKUP` | No |

> **Note**: The operator automatically converts `KEEPALIVED_VIRTUAL_IPS` from comma-separated format to osixia/keepalived's required `#PYTHON2BASH:['ip1','ip2']` format, and auto-generates `KEEPALIVED_UNICAST_PEERS` based on IPs of nodes in the same keepalived group.

## 🔄 How It Works

### Core Workflow

1. **Operator Startup**: Single operator instance starts on Swarm Manager node
2. **Node Discovery**: Scans all nodes, identifies those with matching `keepalived_group` labels
3. **Service Creation**: Creates individual keepalived service instances for each matching node
4. **Priority Assignment**: Sets VRRP priorities based on node labels or default values
5. **Continuous Monitoring**: Checks node label changes and service status every 10 seconds

### Smart Management Features

- **Dynamic Response**: Automatically creates/deletes services when nodes add/remove labels
- **Fault Recovery**: Auto-rebuilds services when they fail
- **Configuration Sync**: Auto-generates and updates UNICAST_PEERS lists
- **Status Monitoring**: Real-time display of all node status and service operation

### Priority Management Strategy

The operator assigns VRRP priorities based on these rules:

- **Custom Priority**: If node has `KEEPALIVED_PRIORITY` label, use that value
- **Default Priority**: If no custom priority is set, use default value 100
- **Full Control**: Complete control over priority assignment via node labels

## 📈 Monitoring and Debugging

### View Operator Status

```bash
# View operator logs
docker service logs -f keepalived-operator

# View all keepalived services
docker service ls --filter name=keepalived-node

# View specific service logs
docker service logs -f keepalived-node-node1-1
```

### Node Status Check

```bash
# View all nodes and their labels
docker node ls --format "table {{.ID}}\t{{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}"

# View specific node details
docker node inspect node1 --pretty
```

### Troubleshooting

```bash
# Check network interfaces
ip addr show

# Check virtual IP status
ip addr show | grep "192.168.1.201"

# Test virtual IP connectivity
ping -c 3 192.168.1.201
```

## 🧪 Testing Deployment

You can verify your deployment by checking the following:

```bash
# Check if the operator is running
docker service ls --filter name=keepalived

# Check operator logs
docker service logs -f keepalived_operator

# Verify keepalived services are created for labeled nodes
docker service ls --filter name=keepalived-node

# Test virtual IP accessibility
ping -c 3 192.168.1.201
```

## 📚 Related Resources

- [Keepalived Official Documentation](https://github.com/acassen/keepalived)
- [osixia/docker-keepalived](https://github.com/osixia/docker-keepalived)
- [Original Project](https://github.com/lhns/docker-swarm-keepalived)
- [Docker Swarm High Availability Guide](https://docs.docker.com/engine/swarm/admin_guide/)
- [VRRP Protocol Specification](https://tools.ietf.org/html/rfc3768)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

## 📄 License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

If you have questions or suggestions, please reach out via:

- Submit an [Issue](https://github.com/isqiao/keepalived-docker-swarm-operator/issues)

---

⭐ If this project helps you, please give it a Star to show your support!
