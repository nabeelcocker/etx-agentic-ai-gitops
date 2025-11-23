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

echo "Applying java-app-build.yaml to namespaces user1-ai-agent to user${NUM_USERS}"
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
    
    # Apply the YAML with namespace and username substitution
    oc apply -f - <<EOF
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: java-app-build
  namespace: ${NAMESPACE}
spec:
  params:
  - default: image-registry.openshift-image-registry.svc:5000
    name: IMAGE_REGISTRY
    type: string
  - default: https://github.com/nstrug/openshift-quickstarts.git
    name: GIT_REPO
    type: string
  - default: bad 
    name: GIT_REVISION
    type: string
  - default: undertow-servlet
    name: SUBDIRECTORY
    type: string
  - name: NAMESPACE
    type: string
  tasks:
  - name: fetch-repository
    retries: 5
    params:
    - name: URL
      value: \$(params.GIT_REPO)
    - name: REVISION
      value: \$(params.GIT_REVISION)
    - name: SUBDIRECTORY
      value: ""
    - name: DELETE_EXISTING
      value: "true"
    taskRef:
      params:
      - name: kind
        value: task
      - name: name
        value: git-clone
      - name: namespace
        value: openshift-pipelines
      resolver: cluster
    workspaces:
    - name: output
      workspace: shared-workspace
  - name: build
    retries: 5
    params:
    - name: IMAGE
      value: \$(params.IMAGE_REGISTRY)/\$(params.NAMESPACE)/\$(params.SUBDIRECTORY)
    - name: TLS_VERIFY
      value: "false"
    - name: CONTEXT
      value: \$(params.SUBDIRECTORY)
    runAfter:
    - fetch-repository
    taskRef:
      params:
      - name: kind
        value: task
      - name: name
        value: s2i-java
      - name: namespace
        value: \$(params.NAMESPACE)
      resolver: cluster
    workspaces:
    - name: source
      workspace: shared-workspace
  finally:
  - name: trigger-agent
    params:
    - name: aggregateTaskStatus
      value: "\$(tasks.status)"
    taskSpec:
      params:
      - name: aggregateTaskStatus
      steps: 
      - name: check-task-status
        image: registry.redhat.io/openshift4/ose-cli:latest
        script: |
          if [ "\$(params.aggregateTaskStatus)" == "Failed" ]
          then
            set -Bx
            echo "Looks like your pipeline failed dumbass, let's find where you messed up"
            failed_pod=\$(oc get pods --field-selector="status.phase=Failed" --sort-by="status.startTime" | grep -v "trigger-agent" | grep "java-app-build" | tail -n 1 | awk '{print \$1}')
            curl -i -H "Content-Type: application/json" -X POST -d "{\"namespace\":\"\$(params.NAMESPACE)\",\"pod_name\":\"\${failed_pod}\",\"container_name\":\"step-s2i-build\"}" http://ai-agent:8000/report-failure
          fi
  workspaces:
  - name: shared-workspace
EOF
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully applied java-app-build to ${NAMESPACE}"
    else
        echo "  ✗ Failed to apply java-app-build to ${NAMESPACE}"
    fi
    echo
done

echo "=================================================================="
echo "Completed applying java-app-build.yaml for users 1 to ${NUM_USERS}"
echo "=================================================================="
