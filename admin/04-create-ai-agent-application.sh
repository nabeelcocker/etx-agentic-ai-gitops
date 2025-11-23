#!/bin/bash

# Check if number of users is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_users>"
    echo "Example: $0 7"
    exit 1
fi

NUM_USERS=$1

# Validate that NUM_USERS is a positive integer
if ! [[ "$NUM_USERS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Number of users must be a positive integer"
    exit 1
fi

echo "Applying application-ai-agent.yaml to namespaces user1-ai-agent to user${NUM_USERS}"
echo "=================================================================="
echo

# Iterate over all users
for i in $(seq 1 ${NUM_USERS}); do
    USERNAME="user${i}"
    NAMESPACE="${USERNAME}-ai-agent"
    
    echo "Processing ${NAMESPACE}..."
    echo "----------------------------------------"
    
    # Check if namespace exists
    if ! oc get namespace "${NAMESPACE}" &>/dev/null; then
        echo "  Warning: Namespace ${NAMESPACE} does not exist, skipping..."
        echo
        continue
    fi
    
    # Apply the application YAML with namespace and username substitution
    oc apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ai-agent
  namespace: ${NAMESPACE}
spec:
  project: default
  source:
    path: agent/chart
    repoURL: https://github.com/rhpds/etx-agentic-ai-gitops.git
    targetRevision: HEAD
    helm:
      values: |
        namespace: ${NAMESPACE}
        agentConfig:
          llamaStackUrl: "http://llamastack-with-config-service.${USERNAME}-llama-stack.svc.cluster.local:8321"
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated: {}
EOF
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully applied application to ${NAMESPACE}"
    else
        echo "  ✗ Failed to apply application to ${NAMESPACE}"
    fi
    echo
done

echo "=================================================================="
echo "Completed applying application-ai-agent.yaml for users 1 to ${NUM_USERS}"
echo "=================================================================="

