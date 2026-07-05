# LLMD-Stack

The goal is to deploy a Helm chart for a multi-tenant, multi-model developer architecture for code generation with LiteLLM, llm-d, vLLM backends and open weights models.

## TODO
    - Use llm-d gateway instead of standalone
    - 

## Install Dependencies
```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.5.0/v1-manifests.yaml

#helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.8.2 -n envoy-gateway-system --create-namespace
#kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
#helm repo add llm-d-infra https://llm-d-incubation.github.io/llm-d-infra/

helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm dependency update

# Install CloudNativePG Operator
helm upgrade --install test   --namespace llmd-stack   --create-namespace   cnpg/cloudnative-pg
```

## Install 
```
helm upgrade --install test . \
  -f values.yaml \
  -f values-singletest.yaml \
  --namespace llmd-stack

kubectl get pods -n llmd-stack
```

Use when updating/changing chart
```
kubectl rollout restart deployment/test-llmd-stack-litellm -n llmd-stack
```

# Pod Test
```
kubectl get pods -n llmd-stack
export IP=$(kubectl get pod test-llmd-stack-model-gemma-4-26B-A4B-it-5794b4cf78-8prps -n llmd-stack  -o jsonpath='{.status.podIP}')
curl -X POST http://${IP}:8000/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
        "model": "google/gemma-4-26B-A4B-it",
        "messages": [
            {"role": "user", "content": "How are you today?"}
        ]
    }' | jq
```

# llm-d router test
```
export IP=$(kubectl get service optimized-baseline-epp -n llmd-stack -o jsonpath='{.spec.clusterIP}')
curl -X POST http://${IP}/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
        "model": "google/gemma-4-26B-A4B-it",
        "messages": [
            {"role": "user", "content": "How are you today?"}
        ]
    }' | jq
```

# LiteLLM Test
```
curl http://localhost:32000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer password" \
  -d '{
    "model": "google/gemma-4-26B-A4B-it",
    "messages": [{"role": "user", "content": "Say hello!"}]
  }' | jq
```

curl http://192.168.0.30:32000/metrics \
  -H "Authorization: Bearer password" 


# LiteLLM UI
http://192.168.0.30:32000/ui/usage/

# Print VSCode Models JSON
```
helm template llmd-stack . -f values-singletest.yaml --show-only templates/copilot-configmap.yaml
```

## Prometheus/Grafana
```
cd prom-g
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prom-crds prometheus-community/prometheus-operator-crds \
  --namespace llmd-stack \
  --create-namespace
helm repo update
helm dependency update
helm template .

helm upgrade --install dev .   -f values.yaml --namespace llmd-stack
```

http://192.168.0.30:32001/login
Username: admin
Password: prom-operator

## Benchmark

genai-perf
```
pip install genai-perf
genai-perf profile \
  -m "google/gemma-4-26B-A4B-it" \
  -u http://192.168.0.30:32000 \
  --header 'Authorization: Bearer password' \
  --endpoint-type chat \
  --synthetic-input-tokens-mean 4000 \
  --synthetic-input-tokens-stddev 0 \
  --output-tokens-mean 1000 \
  --output-tokens-stddev 0 \
  --streaming \
  --request-rate 5.0 \
  --request-count 200 \
  --num-dataset-entries 50 \
  --warmup-request-count 5 \
  --verbose
```

llmdbenchmark (Doesn't work with newer models (gemma4) transformers needs upgraded to >=5.0.0)
```
source .venv/bin/activate
export ENDPOINT_URL="http://$(kubectl get service optimized-baseline-epp -n llmd-stack -o jsonpath='{.spec.clusterIP}')"
llmdbenchmark \
    --spec           guides/optimized-baseline \
    run \
    --endpoint-url   "${ENDPOINT_URL}" \
    --gateway-class  epponly \
    --model          "google/gemma-4-26B-A4B-it" \
    --namespace      llmd-stack \
    --harness        inference-perf \
    --workload       shared_prefix_synthetic.yaml
```

## Troubleshooting

Node stuck in `NotReady` from `kubectl get nodes -A`
```
sudo microk8s stop
sudo microk8s start
```

Error: unable to continue with install: CustomResourceDefinition "backups.postgresql.cnpg.io" in namespace "" exists and cannot be imported into the current release: invalid ownership metadata; annotation validation error: key "meta.helm.sh/release-namespace" must equal "llmd-stack": current value is "llmd-stack"
```
kubectl get crds -o name | grep cnpg.io | xargs kubectl delete
```

PostgreSQL database 
```
kubectl exec -ti -c postgres test-litellm-db-cluster-1 -n llmd-stack -- psql -c '\du'
kubectl exec -ti -c postgres test-litellm-db-cluster-1 -n llmd-stack -- psql -c '\l'
```

## Cleanup 
```
helm uninstall test -n llmd-stack

kubectl delete -n llmd-stack -k guides/optimized-baseline/modelserver/gpu/vllm/gemma4/
kubectl delete pods --all -n llmd-stack
```

