#!/bin/bash

set -e -o pipefail

echo "Running in operator mode, managing keepalived services across the cluster..."

# Check if current node is a manager
if ! docker node ls >/dev/null 2>&1; then
    echo "Error: Operator must run on a manager node" >&2
    exit 1
fi

# Get all nodes in the cluster
all_nodes="$(docker node ls --format '{{.Hostname}}')"
current_node="$(docker node ls --filter role=manager --format '{{.Hostname}}' | head -1)"

# Check if current node is the leader
if [ "$(docker node inspect "$current_node" --format '{{.ManagerStatus.Leader}}')" = "true" ]; then
    if [ -z "$KEEPALIVED_VIRTUAL_IPS" ]; then
        echo "Error: KEEPALIVED_VIRTUAL_IPS environment variable must be set" >&2
        exit 1
    fi

    if [ -z "$KEEPALIVED_GROUP" ]; then
        echo "Error: KEEPALIVED_GROUP environment variable must be set" >&2
        exit 1
    fi

    echo "Looking for nodes with keepalived_group=$KEEPALIVED_GROUP"

    # Print all nodes and their labels
    echo "All nodes and their labels:"
    for node in $all_nodes; do
        node_labels="$(docker node inspect "$node" --format '{{range $k, $v := .Spec.Labels}}{{$k}}={{$v}} {{end}}')"
        if [ -n "$node_labels" ]; then
            echo "  $node: $node_labels"
        else
            echo "  $node: (no labels)"
        fi
    done
    echo ""

    # Filter nodes by keepalived_group label
    matching_nodes=""
    for node in $all_nodes; do
        node_group="$(docker node inspect "$node" --format '{{.Spec.Labels.keepalived_group}}')"
        if [ "$node_group" = "$KEEPALIVED_GROUP" ]; then
            if [ -z "$matching_nodes" ]; then
                matching_nodes="$node"
            else
                matching_nodes="$matching_nodes $node"
            fi
            echo "Node $node matches keepalived_group=$KEEPALIVED_GROUP"
        fi
    done

    if [ -z "$matching_nodes" ]; then
        echo "Error: No nodes found with keepalived_group=$KEEPALIVED_GROUP" >&2
        exit 1
    fi

    echo "Found matching nodes: $matching_nodes"

    # Create keepalived service for each matching node
    node_index=0
    for node in $matching_nodes; do
        node_index=$((node_index + 1))

        # Get priority from node label, default to 100 if not set
        node_priority="$(docker node inspect "$node" --format '{{.Spec.Labels.KEEPALIVED_PRIORITY}}')"
        if [ -n "$node_priority" ] && [ "$node_priority" != "<no value>" ]; then
            priority="$node_priority"
            echo "Using priority from node label: $priority"
        else
            priority=100
            echo "Using default priority: $priority"
        fi

        # Get node IP (try ManagerStatus.Addr first for manager nodes, then Status.Addr for all nodes)
        node_ip="$(docker node inspect "$node" --format '{{if .ManagerStatus.Addr}}{{.ManagerStatus.Addr}}{{else}}{{.Status.Addr}}{{end}}' | cut -d: -f1)"

        echo "Creating keepalived service for node $node (IP: $node_ip) with priority: $priority"

        # Create keepalived service
        service_name="keepalived-node-${node_index}"

        # Check if service already exists
        if ! docker service ls --filter name="$service_name" --format '{{.Name}}' | grep -q "$service_name"; then
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
                "$KEEPALIVED_IMAGE"

            echo "Service $service_name created successfully"
        else
            echo "Service $service_name already exists, skipping creation"
        fi
    done

    echo "Cluster management completed, all keepalived services created for group $KEEPALIVED_GROUP"

    # Monitor service status
    echo "Starting keepalived service monitoring..."
    while true; do
        echo "=== $(date) ==="
        docker service ls --filter name=keepalived-node
        sleep 30
    done

else
    echo "Current node is not the leader, waiting for leader to manage cluster..."
    # Non-leader nodes wait
    while true; do
        sleep 60
    done
fi
