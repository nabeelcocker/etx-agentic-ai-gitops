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

echo "Applying mcp-github.yaml to namespaces user1-llama-stack to user${NUM_USERS}"
echo "=================================================================="
echo

# Iterate over all users
for i in $(seq 1 ${NUM_USERS}); do
    USERNAME="user${i}"
    NAMESPACE="${USERNAME}-llama-stack"
    
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
apiVersion: v1
kind: Secret
metadata:
  name: github-credentials-v1
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  # Add your PAT here
  # Important: not for production use, demo purposes only
  token: ${GITHUB_PAT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-mcp-server
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: github-mcp-server
  template:
    metadata:
      labels:
        app: github-mcp-server
    spec:
      containers:
      - name: github-mcp-server
        image: quay.io/eformat/github-mcp-server:latest
        imagePullPolicy: Always
        command: ["/usr/local/bin/start-server.sh"]
        ports:
        - containerPort: 8080
        env:
        - name: GITHUB_PERSONAL_ACCESS_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-credentials-v1
              key: token
        resources:
          limits:
            memory: "512Mi"
          requests:
            cpu: "200m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: github-mcp-server
  namespace: ${NAMESPACE}
spec:
  selector:
    app: github-mcp-server
  ports:
  - port: 80
    targetPort: 8080
EOF
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully applied mcp-github to ${NAMESPACE}"
    else
        echo "  ✗ Failed to apply mcp-github to ${NAMESPACE}"
    fi
    echo
done

echo "=================================================================="
echo "Completed applying mcp-github.yaml for users 1 to ${NUM_USERS}"
echo "=================================================================="
