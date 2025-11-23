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

echo "Creating ai-agent-pipelinerun.yaml to namespaces user1-ai-agent to user${NUM_USERS}"
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
    
    # Create the YAML with namespace and username substitution
    oc create -f - <<EOF
---
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  # generateName creates a unique name for each run (e.g., agent-service-build-run-abc12).
  generateName: agent-service-build-run-
  namespace: ${NAMESPACE}
spec:
  taskRunTemplate:
    serviceAccountName: pipeline
  pipelineRef:
    # This must match the name of your existing Tekton Pipeline.
    name: agent-service-build
  params:
    - name: GIT_REPO
      value: "https://github.com/rhpds/etx-agentic-ai-gitops.git"
  # Required workspace for the pipeline
  workspaces:
    - name: workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully created ai-agent-pipelinerun to ${NAMESPACE}"
    else
        echo "  ✗ Failed to create ai-agent-pipelinerun to ${NAMESPACE}"
    fi
    echo
done

echo "=================================================================="
echo "Completed creating ai-agent-pipelinerun.yaml for users 1 to ${NUM_USERS}"
echo "=================================================================="
