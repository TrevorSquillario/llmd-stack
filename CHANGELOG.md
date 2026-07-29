# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4]

### Added
- **Global autoscaling defaults**: Moved `autoscaling.prometheusServerAddress` and added `autoscaling.defaultBehavior` under `global.*`. Individual models can now inherit or override scaling behavior. All autoscale values files updated to remove per-model `behavior` blocks in favor of the global default.
- **KEDA keep-alive trigger**: ScaledObject now includes a second Prometheus trigger querying `vllm:num_requests_running` with threshold `"1"`. Prevents the cooldown timer from starting while a request is in flight — the EPP queue depth drops to 0 as soon as a pod starts serving, but the running-requests trigger keeps the pod alive until the request completes.
- **`global.defaultRequestTTL`**: New config option driving EPP Flow Control queue TTL, LiteLLM global `request_timeout`, and per-model `timeout`. Set to 1800s in the homelab config for cold-start scenarios.
- **Cache storage volume**: New `vllm.cacheStorage` section with `hostPath`, `mountPath`, and `readOnly` options. Mounts a hostPath volume for AOT compilation artifacts (Triton, Inductor, FlashInfer). Rendered via new `llmd-stack.cacheStorage.volume` and `llmd-stack.cacheStorage.volumeMount` helpers.
- **Model storage `readOnly`**: New `vllm.modelStorage.readOnly` option for mounting the HF cache volume as read-only.
- **EPP Flow Control separate ConfigMap**: New `epp-flow-control-configmap.yaml` template renders the flow control plugins config as a standalone ConfigMap so Helm template expressions (e.g. `global.defaultRequestTTL`) are expanded. The sub-chart now references it via `pluginsConfigFile: ../config-custom/flow-control-plugins.yaml` with a separate volume mount at `/config-custom`.
- **ServiceMonitor scrape interval**: New `servicemonitor.scrapeInterval` config field (default: `10s`), applied to LiteLLM, vLLM, and EPP ServiceMonitors.
- **LiteLLM `--use_v2_migration_resolver`**: Added to the LiteLLM startup command.
- **LiteLLM per-model `max_input_tokens`**: New field rendered from `model.maxModelLen` in the LiteLLM config.
- **Prometheus global scrape config**: Added `scrapeInterval: 15s` and `evaluationInterval: 15s` to `prom-g/values.yaml` for faster KEDA target discovery.
- **`startup_timer.py`**: New utility script for measuring time-to-first-response from an OpenAI-compatible endpoint.
- **`values-multinode-gb10-homelab.yaml`**: New full homelab deployment config targeting a 2-node GB10 cluster with RDMA, Istio gateway, and four models (Gemma 4 26B A4B IT, DeepSeek-V4-Flash-DSpark, Qwen3.6-35B-A3B, Qwen3.6-27B).

### Changed
- **Replicas logic (single & multi-node)**: When `autoscaling.keda=true`, `.spec.replicas` is omitted from Deployment/LeaderWorkerSet to avoid field manager conflict with KEDA ScaledObject. When `autoscaling.enabled` is true (but not KEDA), replicas come from `autoscaling.minReplicas`.
- **Termination grace period**: vLLM single-node reduced from 300s to 30s; vLLM multi-node reduced from 60s to 30s; LiteLLM reduced from 120s to 30s.
- **`servicemonitor.enabled` default**: Changed from `false` to `true` in `values.yaml`.
- **`servicemonitor.enabled: true` removed**: From all environment-specific values files (`values-single.yaml`, `values-single-istio.yaml`, `values-single-pvc.yaml`, etc.) since it now defaults to `true`.
- **EPP flow control config path**: Changed from inline `pluginsCustomConfig` to a separate ConfigMap mounted at `/config-custom`, referenced via `../config-custom/flow-control-plugins.yaml`.
- **`values-single-istio-autoscale.yaml`**: Scale-up `stabilizationWindowSeconds` reduced from 30 to 0, `periodSeconds` reduced from 30 to 1 for faster cold-start scale-out.
- **README.md**: Added `kubectl events` example, startup timer instructions with benchmark results, and general documentation improvements.
- **`.gitignore`**: Removed `values-local*` entry.

## [1.0.3]

### Added
- **Per-model image override**: New `llmd-stack.model.image` helper template and `model.image.{repository,tag}` config fields, allowing per-model container image overrides while inheriting global defaults.
- **`global.externalUrl`**: New config option for the copilot ConfigMap to use an external endpoint URL instead of internal cluster service URLs.
- **KEDA `cooldownPeriod` and `pollingInterval`**: New configurable autoscaling fields in `values.yaml` and `keda-scaledobject.yaml` for fine-tuning scale-to-zero behavior (defaults: 3600s cooldown, 15s polling).
- **`IPC_LOCK` capability**: Added to single-node vLLM container security context for improved memory locking.
- **`--distributed-executor-backend mp`**: Added to multi-node vLLM args for multiprocessing distributed executor backend.
- **`values-local*` to `.gitignore`**: Prevents local values files from being committed.
- **`docker/` to `.helmignore`**: Excludes the docker build directory from Helm packaging.

### Changed
- **LiteLLM nodePort**: Changed from `32000` to `32020` in `values.yaml` and all documentation.
- **Copilot ConfigMap name**: Changed from `"vLLM"` to `"LiteLLM"` to reflect the correct endpoint.
- **`_helpers.tpl`**: `model.env` helper now supports map-type values in `extraEnv` (previously only string values).
- **Probe `initialDelaySeconds`**: Increased from 15 to 60 for multi-node vLLM containers to allow more time for CUDA context initialization.
- **README.md**: Major restructuring — reorganized section headings, updated LiteLLM port references, added sections for k8s container registry setup, cold start optimization (instanttensor), DGX Spark/GB10 specific builds, and improved troubleshooting docs.

### Fixed
- **`model.env` helper**: Now correctly renders map-type `extraEnv` values (e.g., `valueFrom` / `configMapKeyRef`) instead of forcing them to strings.

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
- **LiteLLM service type**: Changed from `ClusterIP` to `NodePort` with explicit `nodePort: 32020`.
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
