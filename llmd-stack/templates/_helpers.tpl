{{- /*
Shared Template Helpers
SPDX-License-Identifier: Apache-2.0
*/}}

{{- define "llmd-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "llmd-stack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "llmd-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "llmd-stack.labels" -}}
helm.sh/chart: {{ include "llmd-stack.chart" . }}
{{ include "llmd-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- range $key, $value := .Values.global.labels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{- define "llmd-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "llmd-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "llmd-stack.litellm.labels" -}}
{{ include "llmd-stack.selectorLabels" . }}
app.kubernetes.io/component: litellm
{{- end }}

{{- define "llmd-stack.model.labels" -}}
{{ include "llmd-stack.selectorLabels" . }}
app.kubernetes.io/component: vllm
{{- end }}

{{- /*
Create a name for a model-specific sub-resource.
Usage: {{ include "llmd-stack.modelResourceName" (dict "name" "code-fast" "ctx" $) }}
*/}}
{{- define "llmd-stack.modelResourceName" -}}
{{- printf "%s-model-%s" (include "llmd-stack.fullname" .ctx) .name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
Return the shared vLLM environment variables.
*/}}
{{- define "llmd-stack.vllm.sharedEnv" -}}
{{- range $key, $value := .Values.vllm.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}

{{- /*
Return the full set of environment variables for a specific model deployment.
Takes a dict with "model" (the model config) and "ctx" (the root context).
*/}}
{{- define "llmd-stack.model.env" -}}
{{ include "llmd-stack.vllm.sharedEnv" .ctx }}
- name: MODEL_NAME
  value: {{ .model.name | quote }}
- name: MODEL_PATH
  value: {{ .model.model | quote }}
- name: TENSOR_PARALLEL_SIZE
  value: {{ .model.tensorParallelSize | quote }}
- name: PIPELINE_PARALLEL_SIZE
  value: {{ .model.pipelineParallelSize | quote }}
- name: MAX_MODEL_LEN
  value: {{ .model.maxModelLen | quote }}
- name: GPU_MEMORY_UTILIZATION
  value: {{ .model.gpuMemoryUtilization | quote }}
{{- if .model.dtype }}
- name: DTYPE
  value: {{ .model.dtype | quote }}
{{- end }}
- name: PORT
  value: {{ .model.port | quote }}
{{- range $key, $value := .model.extraEnv }}
- name: {{ $key }}
{{- if kindIs "map" $value }}
  {{- toYaml $value | nindent 2 }}
{{- else }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- /* vLLM args removed — templates now render args inline to accept explicit values */}}

{{- /*
Resolve the container image for a model.
Supports per-model image override via $model.image.repository and $model.image.tag.
Either field can be omitted to inherit the global default.
Usage: {{ include "llmd-stack.model.image" (dict "model" $model "ctx" $) }}
*/}}
{{- define "llmd-stack.model.image" -}}
{{- $repo := dig "image" "repository" .ctx.Values.vllm.image.repository .model -}}
{{- $tag  := dig "image" "tag"        .ctx.Values.vllm.image.tag        .model -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end }}

{{- /*
Render the model-storage volume definition.
Uses hostPath when .Values.vllm.modelStorage.hostPath is set, otherwise PVC.
*/}}
{{- define "llmd-stack.modelStorage.volume" -}}
- name: model-storage
{{- if $.Values.vllm.modelStorage.hostPath }}
  hostPath:
    path: {{ $.Values.vllm.modelStorage.hostPath }}
    type: DirectoryOrCreate
{{- else }}
  persistentVolumeClaim:
    claimName: {{ include "llmd-stack.fullname" $ }}-model-storage
{{- end }}
{{- end }}

{{- /*
Render the model-storage volume mount.
*/}}
{{- define "llmd-stack.modelStorage.volumeMount" -}}
- name: model-storage
  mountPath: {{ $.Values.vllm.modelStorage.mountPath }}
{{- end }}

{{- /*
Set llm-d api base path
Overridable via .Values.litellm.apiBasePath for custom routing.
*/}}
{{- define "llmd-stack.apiBasePath" -}}
{{- if .Values.litellm.apiBasePath -}}
{{- .Values.litellm.apiBasePath -}}
{{- else if index .Values "llm-d-router-standalone" "router" "enabled" -}}
{{- printf "http://%s-epp.%s.svc.%s/v1" .Release.Name .Release.Namespace .Values.global.clusterDomain -}}
{{- end -}}
{{- end -}}

{{- /*
Build the Postgres DATABASE_URL, resolving the host to a FQDN when the
Postgres cluster is deployed in a different namespace than the release.
*/}}
{{- define "llmd-stack.postgresDatabaseUrl" -}}
{{- $host := default (printf "%s-litellm-db-cluster-rw" .Release.Name) .Values.postgres.host -}}
{{- if and (ne .Values.postgres.namespace .Release.Namespace) (not (contains "." $host)) -}}
{{- $host = printf "%s.%s.svc.%s" $host .Values.postgres.namespace .Values.global.clusterDomain -}}
{{- end -}}
{{- printf "postgresql://%s:%s@%s:%v/%s" .Values.postgres.postgresqlUsername .Values.postgres.postgresqlPassword $host .Values.postgres.service.port .Values.postgres.postgresqlDatabase -}}
{{- end -}}