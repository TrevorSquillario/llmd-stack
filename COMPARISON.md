# Feature Comparison: LLM Inference Stacks on Kubernetes

This document compares **llmd-stack** against three other open-source Kubernetes-native LLM inference deployment projects. AI generated, may container mistakes :)

## Core Architecture

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **Serving Engine** | vLLM | vLLM | llm-d (standalone) | vLLM, Ollama, FasterWhisper, Infinity |
| **API Proxy** | LiteLLM | Custom Python router | llm-d Gateway / EPP | Custom Go proxy |
| **OpenAI-Compatible API** | ✅ (via LiteLLM) | ✅ (via router) | ✅ (via llm-d) | ✅ (native) |
| **Multi-Model Support** | ✅ | ✅ | ✅ | ✅ |
| **Multi-Node Serving** | ✅ (LeaderWorkerSet + NCCL) | ✅ (RayCluster via KubeRay) | ❌ | ❌ |
| **Operator/CRD** | ❌ (Helm-only) | ❌ (Helm-only) | ❌ (Helm-only) | ✅ (Model CRD operator) |
| **Model Catalog** | ❌ | ❌ | ❌ | ✅ (pre-configured models) |

---

## Routing & Load Balancing

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **Smart Routing** | ✅ (llm-d EPP — queue depth, KV-cache, prefix cache) | ✅ (custom router) | ✅ (llm-d Gateway) | ✅ (prefix-aware CHWBL) |
| **Round-Robin** | ✅ | ✅ | ✅ | ✅ |
| **Session-ID Routing** | ❌ | ✅ | ❌ | ❌ |
| **Prefix-Aware Routing** | ✅ (via llm-d) | ✅ (WIP) | ✅ (via llm-d) | ✅ (core feature) |
| **KV-Cache-Aware Routing** | ✅ (via llm-d) | ✅ (via LMCache controller) | ✅ (via llm-d) | ✅ (prefix-hash) |
| **Disaggregated Prefill** | ✅ | ✅ (orchestrated) | ✅ | ✅ |
| **Model Aliases** | ✅ | ✅ | ❌ | ❌ |
| **Request Queueing** | ✅ | ❌ | ❌ | ✅ (scale-from-zero) |
| **Request Retries** | ✅ (LiteLLM) | ❌ | ❌ | ✅ |

---

## Autoscaling

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **KEDA Integration** | ✅ (vllm:num_requests_waiting) | ✅ (Prometheus triggers) | ❌ | ❌ (built-in) |
| **Scale-to-Zero** | ✅ (via KEDA) | ✅ (via KEDA idleReplicaCount) | ❌ | ✅ (built-in) |
| **HPA Support** | ✅ (LiteLLM) | ❌ | ❌ | ❌ |
| **Prometheus Adapter** | ✅ | ✅ | ❌ | ❌ |
| **Built-in Autoscaler** | ✅ | ❌ | ❌ | ✅ (native operator) |

---

## Observability

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **Prometheus ServiceMonitor** | ✅ (vLLM + LiteLLM) | ✅ (vLLM + Router) | ❌ | ❌ |
| **Grafana Dashboards** | ✅ (LiteLLM + vLLM + llm-d) | ✅ (vLLM + LMCache) | ❌ | ❌ |
| **OpenTelemetry Tracing** | ❌ | ✅ (router) | ❌ | ❌ |
| **LiteLLM UI** | ✅ | ❌ | ❌ | ❌ |
| **Open WebUI** | ❌ | ❌ | ❌ | ✅ (bundled) |

---

## Storage & Model Management

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **PVC Model Storage** | ✅ | ✅ (shared PVC) | ❌ | ✅ (model caching) |
| **Init Containers** | ❌ | ✅ (model download) | ❌ | ✅ (model loader) |
| **OCI Image Models** | ❌ | ❌ | ❌ | ✅ |
| **LoRA Adapters** | ❌ | ✅ (controller + CRD) | ❌ | ✅ (dynamic adapters) |
| **KV Cache Offloading** | ❌ | ✅ (LMCache CPU + disk) | ❌ | ❌ |

---

## Networking & Gateway

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **K8s Gateway API** | ✅ (HTTPRoute) | ❌ | ✅ (primary feature) | ❌ |
| **Istio Integration** | ✅ (Inference Extension) | ❌ | ✅ | ❌ |
| **Ingress Support** | ❌ | ✅ | ✅ | ❌ |
| **TLS Configuration** | ❌ | ❌ | ✅ | ❌ |
| **NetworkPolicy (zero-trust)** | ✅ | ❌ | ❌ | ❌ |
| **NVIDIA RDMA/Infiniband** | ✅ (Network Operator) | ❌ | ❌ | ❌ |
| **External Load Balancer** | ❌ | ❌ | ❌ | ✅ (proposed) |

---

## Database & Persistence

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **PostgreSQL (usage tracking)** | ✅ (CloudNativePG) | ❌ | ❌ | ❌ |
| **Event Streaming (Kafka/PubSub)** | ❌ | ❌ | ❌ | ✅ |

---

## Multi-Platform Support

| Feature | llmd-stack | vLLM Production Stack | llm-d-infra | KubeAI |
|---|---|---|---|---|
| **CPU Inference** | ❌ | ❌ | ❌ | ✅ |
| **GPU Inference** | ✅ (NVIDIA) | ✅ (NVIDIA) | ✅ | ✅ |
| **TPU Inference** | ❌ | ❌ | ❌ | ✅ |
| **Cloud Deployment Tutorials** | ❌ | ✅ (AWS, GCP, Lambda) | ❌ | ✅ (Lambda, Vultr) |

---

## Summary

| Project | Best For |
|---|---|
| **llmd-stack** | Multi-tenant code generation with LiteLLM auth/rate-limiting, multi-node vLLM via LeaderWorkerSet, llm-d smart routing, and full observability stack |
| **vLLM Production Stack** | vLLM-native deployments needing KV cache offloading (LMCache), LoRA adapters, Ray-based multi-node, and rich observability |
| **llm-d-infra** | **Archived** — was the infrastructure layer for llm-d gateway (Gateway API, Istio, agentgateway); functionality now lives in the main llm-d repo |
| **KubeAI** | Simplicity-first operator with built-in autoscaling, model catalog, multi-engine support (vLLM + Ollama + Whisper + Infinity), and zero external dependencies |
