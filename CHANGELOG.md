# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2]

### Added
- **EPP Flow Control support**: New `flow-control-plugins.yaml` EPP config with feature gates, concurrency detector, priority bands (100/0/-10), round-robin fairness, and FCFS ordering policies for request buffering during cold starts.
- **EPP metric path for KEDA ScaledObject**: ScaledObject now queries `llm_d_epp_flow_control_queue_size` when the llm-d router is enabled, enabling scale-from-zero via EPP Flow Control.
- **ServiceMonitor for llm-d EPP**: New ServiceMonitor scraping EPP metrics at `/metrics` on a 10s interval with bearer token auth.
- **Grafana persistence**: Enabled PVC-backed persistence (10Gi) for Grafana dashboards and settings in `prom-g/values.yaml`.
- **Per-model `eppMetricQuery`**: New config option to override the default EPP Flow Control PromQL query per model.
- **README**: Added `kubectl logs` by label examples for EPP gateway and vLLM pods.

### Changed
- **Scale-to-zero mechanism**: Replaced KEDA HTTP Add-on interceptor with llm-d EPP Flow Control for scale-to-zero. The EPP buffers requests during cold starts, eliminating 5xx errors when scaling from 0.
- **`vllm-model-single.yaml`**: Replicas field is now omitted when `autoscaling.keda=true` AND `minReplicas=0` (instead of when `kedaHttpInterceptor.enabled`), preventing Deployment controller / KEDA replica count conflicts.
- **`values-single-istio-autoscale.yaml`**: Completely rewritten from KEDA HTTP interceptor architecture to EPP Flow Control architecture with updated documentation, prerequisites, and scaling behavior policies.
- **`values-multinode-gb10-autoscale.yaml`**: `minReplicas` changed from 1 to 0 for scale-to-zero; `enabled` field reordered.
- **`values.yaml` defaults**: `llm-d-router-standalone.router.enabled` changed from `false` to `true`; EPP plugins switched from `optimized-baseline-plugins.yaml` to `flow-control-plugins.yaml`; log verbosity reduced from 4 to 2.
- **`litellm-deployment.yaml`**: `ENFORCE_PRISMA_MIGRATION_CHECK` re-enabled to `"true"`.

### Removed
- **`kedaHttpInterceptor` section**: Removed from `values.yaml` (global config, per-model `kedaHttp` overrides, and all documentation).
- **`keda-http-interceptor.yaml` template**: Entire InterceptorRoute + external-push ScaledObject template deleted.
- **KEDA HTTP interceptor references**: Removed from `litellm-configmap.yaml` (LiteLLM routing through interceptor proxy), `networkpolicy.yaml` (interceptor ingress/egress rules), and `keda-scaledobject.yaml` (interceptor guard condition).
- **PVC template**: Removed from `vllm-model-single.yaml` (now handled by `model-storage-pvc.yaml`).
- **`llm-d-router-standalone.router.enabled: false`**: Removed from `values-single-istio.yaml` (now inherits default `true` from `values.yaml`).

## [1.0.1]

### Added
- **LiteLLM deployment**: Init container for UI setup, security context (non-root, read-only root filesystem), topology spread constraints, rolling update strategy, lifecycle preStop hook, and emptyDir volumes for UI assets, cache, migrations, and Prometheus multiprocess metrics.
- **LiteLLM autoscaling**: HPA configuration with configurable min/max replicas, CPU/memory utilization targets, and scale-up/down behavior policies.
- **LiteLLM migration job**: Helm pre-install/pre-upgrade hook with configurable backoff limit, TTL, and ArgoCD support.
- **LiteLLM `apiBasePath` override**: New field to override the auto-detected llm-d router service URL for custom routing.
- **vLLM autoscaling defaults**: Global Prometheus server address for KEDA Prometheus scaler, configurable per-model.
- **Kubernetes version constraint**: Chart now requires `>=1.28.0-0`.
- **Gateway resource**: New `gateway` section replacing the old `llm-d-infra.gateway` subchart, supporting Istio Gateway class.
- **NetworkPolicy support**: New `networkPolicy.enabled` flag for zero-trust network isolation.
- **NVIDIA Network Operator (NVNO)**: New `nvno.rdmaSharedDevicePlugin` section with configurable enable/disable and inline JSON config.
- **PostgreSQL cluster resources**: Pod-level resource requests/limits for CloudNativePG cluster.
- **ServiceMonitor for vLLM**: Separate ServiceMonitor targeting pods with `app.kubernetes.io/model-name` label.
- **Configurable `dshmSizeLimit`**: Per-model field for shared memory size (defaults to 16Gi single-node, 32Gi multi-node).
- **New environment variables**: `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`, `VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0`, `NCCL_ASYNC_ERROR_HANDLING=1` on vLLM containers.
- **New values files**: `values-single-autoscale.yaml` and `values-multinode-gb10-autoscale.yaml`.
- **`.helmignore`**: Expanded to exclude artifacts, git, CI, tests, markdown, and docs directories.
- **`aiperf` benchmark commands**: Updated README with `aiperf` CLI examples replacing deprecated `genai-perf` and `llmdbenchmark`.

### Changed
- **Unified model definitions**: Merged `modelsSingleNode` and `modelsMultiNode` into a single `models` list. The `nodes` field determines single-node (Deployment) vs multi-node (LeaderWorkerSet) rendering.
- **LiteLLM image**: Updated from `docker.litellm.ai/berriai/litellm:latest` to `ghcr.io/berriai/litellm:v1.92.1`.
- **LiteLLM service type**: Changed from `ClusterIP` to `NodePort` with explicit `nodePort: 32000`.
- **LiteLLM resources**: Increased limits to 4 CPU / 12Gi memory and requests to 2 CPU / 10Gi memory.
- **LiteLLM config mount**: Changed from `/etc/litellm` to `/app/config.yaml` (subPath).
- **LiteLLM migration check**: `ENFORCE_PRISMA_MIGRATION_CHECK` set to `"false"` (was `"true"`).
- **vLLM command pattern**: Changed from `vllm serve` to `exec vllm serve` for proper signal handling.
- **vLLM pipeline parallelism**: Multi-node templates now use `pipelineParallelSize` from values instead of `$(LWS_GROUP_SIZE)`.
- **vLLM probe settings**: Startup probe allows up to 30 minutes for model loading (180 failures × 10s). Liveness/readiness probes have zero initial delay (delegated to startup probe).
- **vLLM hostPID**: Removed `hostPID: true` from multi-node worker template.
- **vLLM termination grace period**: Set to 60s with preStop sleep 30s for graceful shutdown.
- **HF download env**: Replaced `HF_HUB_ENABLE_HF_TRANSFER=1` with `HF_XET_HIGH_PERFORMANCE=1`.
- **ServiceMonitor**: Split into separate LiteLLM and vLLM ServiceMonitors with targeted label selectors.
- **Postgres DATABASE_URL**: Now rendered via `llmd-stack.postgresDatabaseUrl` helper template.
- **NicClusterPolicy**: Made conditional on `nvno.rdmaSharedDevicePlugin.enabled` with dynamic config from values.
- **llm-d-router-standalone**: Disabled by default (`router.enabled: false`).
- **README.md**: Simplified architecture diagram, updated benchmark commands to `aiperf`, changed all model references from `google/gemma-4-26B-A4B-it` to `Qwen/Qwen2.5-0.5B-Instruct`, added Grafana/Prometheus URLs.
- **Values files**: All environment-specific values files updated to use unified `models` list, removed LiteLLM override sections (now inherit from `values.yaml` defaults), and switched to Qwen2.5-0.5B-Instruct for smoke testing.

### Fixed
- **LiteLLM service nodePort**: Removed default fallback to prevent silent port assignment issues.
- **PostgreSQL secret**: Uses helper template for consistent DATABASE_URL generation.
- **Security warnings**: Added inline warnings in `values.yaml` about insecure default credentials for LiteLLM and PostgreSQL.
- **vLLM multi-node leader labels**: Removed redundant `app.kubernetes.io/model-name`, `model-port`, and `tensor-parallel-size` labels from headless service.

### Removed
- **`llm-d-infra` subchart dependency**: Removed from `Chart.yaml` and `Chart.lock`. Gateway functionality replaced by new `gateway` section.
- **`values-production.yaml`**: Full production configuration file removed.
- **`dns-test.yaml`**: DNS test StatefulSet and headless service removed.
- **`llm-d-servicemonitor.yaml`**: Separate llm-d gateway ServiceMonitor template removed (monitoring consolidated into `servicemonitor.yaml`).
- **LiteLLM override sections**: Removed from all environment-specific values files (`values-single.yaml`, `values-single-istio.yaml`, `values-multinode-gb10.yaml`).
