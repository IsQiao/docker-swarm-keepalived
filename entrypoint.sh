#!/bin/bash

set -e -o pipefail

echo "Running in operator mode, managing keepalived services across the cluster..."

# Check if current node is a manager
if ! docker node ls >/dev/null 2>&1; then
    echo "Error: Operator must run on a manager node" >&2
    exit 1
fi

# Function to get matching nodes
get_matching_nodes() {
    local group="$1"
    local all_nodes="$(docker node ls --format '{{.Hostname}}')"
    local matching_nodes=""

    for node in $all_nodes; do
        local node_group="$(docker node inspect "$node" --format '{{.Spec.Labels.keepalived_group}}' 2>/dev/null || echo "")"
        if [ "$node_group" = "$group" ]; then
            if [ -z "$matching_nodes" ]; then
                matching_nodes="$node"
            else
                matching_nodes="$matching_nodes $node"
            fi
        fi
    done

    echo "$matching_nodes"
}

# Function to get current keepalived services
get_current_services() {
    docker service ls --filter name=keepalived-node --format '{{.Name}}' 2>/dev/null || echo ""
}

# Function to create keepalived service for a node
create_keepalived_service() {
    local node="$1"
    local service_name="$2"

    # Get priority from node label, default to 100 if not set
    local node_priority="$(docker node inspect "$node" --format '{{.Spec.Labels.KEEPALIVED_PRIORITY}}' 2>/dev/null || echo "")"
    if [ -n "$node_priority" ] && [ "$node_priority" != "<no value>" ] && [ "$node_priority" != "" ]; then
        local priority="$node_priority"
        echo "Using priority from node label for $node: $priority"
    else
        local priority=100
        echo "Using default priority for $node: $priority"
    fi

    # Get node IP
    local node_ip="$(docker node inspect "$node" --format '{{if .ManagerStatus}}{{.ManagerStatus.Addr}}{{else}}{{.Status.Addr}}{{end}}' 2>/dev/null | cut -d: -f1)"

    echo "Creating keepalived service $service_name for node $node (IP: $node_ip) with priority: $priority"

    # Create service
    docker service create \
        --name "$service_name" \
        --constraint "node.hostname==$node" \
        --network host \
        --cap-add NET_ADMIN \
        --cap-add NET_BROADCAST \
        --cap-add NET_RAW \
        --env KEEPALIVED_INTERFACE="$KEEPALIVED_INTERFACE" \
        --env KEEPALIVED_PASSWORD="$KEEPALIVED_PASSWORD" \
        --env KEEPALIVED_PRIORITY="$priority" \
        --env KEEPALIVED_ROUTER_ID="$KEEPALIVED_ROUTER_ID" \
        --env KEEPALIVED_IP="$node_ip" \
        --env KEEPALIVED_UNICAST_PEERS="$KEEPALIVED_UNICAST_PEERS" \
        --env KEEPALIVED_VIRTUAL_IPS="$KEEPALIVED_VIRTUAL_IPS" \
        --env KEEPALIVED_NOTIFY="$KEEPALIVED_NOTIFY" \
        --env KEEPALIVED_COMMAND_LINE_ARGUMENTS="$KEEPALIVED_COMMAND_LINE_ARGUMENTS" \
        --env KEEPALIVED_STATE="$KEEPALIVED_STATE" \
        "${KEEPALIVED_IMAGE:-osixia/keepalived:2.0.20}" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "Service $service_name created successfully"
    else
        echo "Failed to create service $service_name"
    fi
}

# Function to remove keepalived service
remove_keepalived_service() {
    local service_name="$1"
    echo "Removing keepalived service: $service_name"
    docker service rm "$service_name" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Service $service_name removed successfully"
    else
        echo "Failed to remove service $service_name"
    fi
}

# Function to sync services with current node labels
sync_keepalived_services() {
    local group="$1"

    echo "=== Syncing keepalived services ==="

    # Get current matching nodes and services
    local matching_nodes="$(get_matching_nodes "$group")"
    local current_services="$(get_current_services)"

    echo "Nodes with keepalived_group=$group: $matching_nodes"
    echo "Current services: $current_services"

    # Create a map of node to service name for existing services
    # Extract node names from service names (format: keepalived-node-NODENAME-INDEX)
    local existing_node_services=""
    for service in $current_services; do
        # Extract node name from service name (remove keepalived-node- prefix and -INDEX suffix)
        local node_from_service=$(echo "$service" | sed 's/keepalived-node-//' | sed 's/-[0-9]*$//')
        existing_node_services="$existing_node_services $node_from_service:$service"
    done

    # Remove services for nodes that no longer have the keepalived_group label
    for service in $current_services; do
        local node_from_service=$(echo "$service" | sed 's/keepalived-node-//' | sed 's/-[0-9]*$//')
        local should_keep=false

        for node in $matching_nodes; do
            if [ "$node" = "$node_from_service" ]; then
                should_keep=true
                break
            fi
        done

        if [ "$should_keep" = false ]; then
            echo "Node $node_from_service no longer matches group $group, removing service"
            remove_keepalived_service "$service"
        fi
    done

    # Create services for new nodes that have the keepalived_group label
    local node_index=0
    for node in $matching_nodes; do
        node_index=$((node_index + 1))
        local service_name="keepalived-node-${node}-${node_index}"
        local service_exists=false

        # Check if a service for this node already exists
        for service in $current_services; do
            local existing_node=$(echo "$service" | sed 's/keepalived-node-//' | sed 's/-[0-9]*$//')
            if [ "$existing_node" = "$node" ]; then
                service_exists=true
                echo "Service for node $node already exists: $service"
                break
            fi
        done

        if [ "$service_exists" = false ]; then
            echo "Node $node has new keepalived_group=$group label, creating service"
            create_keepalived_service "$node" "$service_name"
        fi
    done

    echo "=== Sync completed ==="
}

# Get current node and check if it's the leader
current_node="$(docker node ls --filter role=manager --format '{{.Hostname}}' | head -1)"

if [ "$(docker node inspect "$current_node" --format '{{.ManagerStatus.Leader}}')" = "true" ]; then
    if [ -z "$KEEPALIVED_VIRTUAL_IPS" ]; then
        echo "Error: KEEPALIVED_VIRTUAL_IPS environment variable must be set" >&2
        exit 1
    fi

    if [ -z "$KEEPALIVED_GROUP" ]; then
        echo "Error: KEEPALIVED_GROUP environment variable must be set" >&2
        exit 1
    fi

    echo "Current node is the leader, starting cluster management..."
    echo "Monitoring for nodes with keepalived_group=$KEEPALIVED_GROUP"

    # Initial sync
    sync_keepalived_services "$KEEPALIVED_GROUP"

    # Continuous monitoring loop
    echo "Starting continuous monitoring (check every 10 seconds)..."
    while true; do
        sleep 10
        echo ""
        echo "=== $(date) ==="

        # Print all nodes and their labels for debugging
        echo "All nodes and their labels:"
        all_nodes="$(docker node ls --format '{{.Hostname}}')"
        for node in $all_nodes; do
            node_labels="$(docker node inspect "$node" --format '{{range $k, $v := .Spec.Labels}}{{$k}}={{$v}} {{end}}' 2>/dev/null || echo "")"
            node_status="$(docker node inspect "$node" --format '{{.Status.State}}' 2>/dev/null || echo "unknown")"
            if [ -n "$node_labels" ]; then
                echo "  $node [$node_status]: $node_labels"
            else
                echo "  $node [$node_status]: (no labels)"
            fi
        done
        echo ""

        # Sync services based on current labels
        sync_keepalived_services "$KEEPALIVED_GROUP"

        # Show current service status
        echo ""
        echo "Current keepalived services:"
        if [ -n "$(get_current_services)" ]; then
            docker service ls --filter name=keepalived-node --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}" 2>/dev/null
        else
            echo "No keepalived services currently running"
        fi
        echo ""
    done

else
    echo "Current node is not the leader, waiting for leader to manage cluster..."
    # Non-leader nodes wait
    while true; do
        sleep 60
    done
fi
