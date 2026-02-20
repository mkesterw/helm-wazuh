{{/*
=============================================================================
_helpers.tpl - Template helpers para o Wazuh Helm Chart
=============================================================================
*/}}

{{/*
=============================================================================
Helpers de imagem - usam wazuhVersion como fallback global
Se image.<componente>.tag estiver definido, usa ele.
Caso contrário, usa .Values.wazuhVersion.
Isso garante que alterar só wazuhVersion atualiza todos os componentes.
=============================================================================
*/}}

{{- define "wazuh.image.manager" -}}
{{- printf "%s:%s" .Values.image.manager.repository (.Values.image.manager.tag | default .Values.wazuhVersion) -}}
{{- end }}

{{- define "wazuh.image.indexer" -}}
{{- printf "%s:%s" .Values.image.indexer.repository (.Values.image.indexer.tag | default .Values.wazuhVersion) -}}
{{- end }}

{{- define "wazuh.image.dashboard" -}}
{{- printf "%s:%s" .Values.image.dashboard.repository (.Values.image.dashboard.tag | default .Values.wazuhVersion) -}}
{{- end }}

{{/*
Nome base do chart
*/}}
{{- define "wazuh.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Nome completo do release (release-name + chart-name, ou fullnameOverride)
Para multi-tenant com namespace por cliente, use fullnameOverride: "wazuh"
*/}}
{{- define "wazuh.fullname" -}}
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

{{/*
Chart label (nome/versão)
*/}}
{{- define "wazuh.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels padrão do Helm
*/}}
{{- define "wazuh.labels" -}}
helm.sh/chart: {{ include "wazuh.chart" . }}
app.kubernetes.io/name: {{ include "wazuh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.manager.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
=============================================================================
Nomes dos componentes
=============================================================================
*/}}

{{- define "wazuh.indexer.fullname" -}}
{{- printf "%s-indexer" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "wazuh.dashboard.fullname" -}}
{{- printf "%s-dashboard" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "wazuh.manager.master.fullname" -}}
{{- printf "%s-manager-master" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "wazuh.manager.worker.fullname" -}}
{{- printf "%s-manager-worker" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "wazuh.certgen.fullname" -}}
{{- printf "%s-cert-gen" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
=============================================================================
Nomes dos Services
=============================================================================
*/}}

{{/* Headless service do indexer - usado para descoberta do cluster OpenSearch */}}
{{- define "wazuh.indexer.svc" -}}
{{- include "wazuh.indexer.fullname" . }}
{{- end }}

{{/* Headless service do cluster Wazuh - comunicação entre master e workers */}}
{{- define "wazuh.manager.cluster.svc" -}}
{{- printf "%s-cluster" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Service da API do Wazuh (porta 55000) */}}
{{- define "wazuh.manager.api.svc" -}}
{{- printf "%s-api" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Service de eventos dos agentes (porta 1514, workers) */}}
{{- define "wazuh.manager.events.svc" -}}
{{- printf "%s-events" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Service de registro dos agentes (porta 1515, master) */}}
{{- define "wazuh.manager.registration.svc" -}}
{{- printf "%s-registration" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Service do dashboard */}}
{{- define "wazuh.dashboard.svc" -}}
{{- printf "%s-dashboard" (include "wazuh.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
=============================================================================
Seed hosts do OpenSearch para descoberta de cluster
Gera: "release-indexer-0.release-indexer,release-indexer-1.release-indexer,..."
=============================================================================
*/}}
{{- define "wazuh.indexer.seedHosts" -}}
{{- $fullname := include "wazuh.indexer.fullname" . -}}
{{- $replicas := .Values.indexer.replicas | int -}}
{{- range $i, $e := until $replicas -}}
{{- if $i }},{{ end -}}
{{- $fullname }}-{{ $i }}.{{ $fullname -}}
{{- end -}}
{{- end }}

{{/*
=============================================================================
Nomes dos Secrets
=============================================================================
*/}}

{{- define "wazuh.secret.indexerCerts" -}}
{{- printf "%s-indexer-certs" (include "wazuh.fullname" .) }}
{{- end }}

{{- define "wazuh.secret.dashboardCerts" -}}
{{- printf "%s-dashboard-certs" (include "wazuh.fullname" .) }}
{{- end }}

{{- define "wazuh.secret.indexerCred" -}}
{{- if .Values.secrets.indexer.existingSecret -}}
{{- .Values.secrets.indexer.existingSecret -}}
{{- else -}}
{{- printf "%s-indexer-cred" (include "wazuh.fullname" .) -}}
{{- end }}
{{- end }}

{{- define "wazuh.secret.dashboardCred" -}}
{{- if .Values.secrets.dashboard.existingSecret -}}
{{- .Values.secrets.dashboard.existingSecret -}}
{{- else -}}
{{- printf "%s-dashboard-cred" (include "wazuh.fullname" .) -}}
{{- end }}
{{- end }}

{{- define "wazuh.secret.apiCred" -}}
{{- if .Values.secrets.wazuhApi.existingSecret -}}
{{- .Values.secrets.wazuhApi.existingSecret -}}
{{- else -}}
{{- printf "%s-api-cred" (include "wazuh.fullname" .) -}}
{{- end }}
{{- end }}

{{- define "wazuh.secret.authdPass" -}}
{{- if .Values.secrets.authdExistingSecret -}}
{{- .Values.secrets.authdExistingSecret -}}
{{- else -}}
{{- printf "%s-authd-pass" (include "wazuh.fullname" .) -}}
{{- end }}
{{- end }}

{{- define "wazuh.secret.clusterKey" -}}
{{- if .Values.secrets.clusterKeyExistingSecret -}}
{{- .Values.secrets.clusterKeyExistingSecret -}}
{{- else -}}
{{- printf "%s-cluster-key" (include "wazuh.fullname" .) -}}
{{- end }}
{{- end }}

{{/*
=============================================================================
Nome da StorageClass efetiva
=============================================================================
*/}}
{{- define "wazuh.storageClass" -}}
{{- if .Values.storageClass.create -}}
{{- .Values.storageClass.name -}}
{{- else -}}
{{- .Values.storageClass.name -}}
{{- end -}}
{{- end }}

{{/*
=============================================================================
ServiceAccounts
=============================================================================
*/}}

{{- define "wazuh.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "wazuh.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "wazuh.certgen.serviceAccountName" -}}
{{- printf "%s-cert-gen" (include "wazuh.fullname" .) }}
{{- end }}

{{/*
=============================================================================
Labels de seleção (selector) por componente
=============================================================================
*/}}

{{- define "wazuh.indexer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wazuh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: indexer
app: wazuh-indexer
{{- end }}

{{- define "wazuh.dashboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wazuh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: dashboard
app: wazuh-dashboard
{{- end }}

{{- define "wazuh.manager.master.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wazuh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: manager-master
app: wazuh-manager
node-type: master
{{- end }}

{{- define "wazuh.manager.worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wazuh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: manager-worker
app: wazuh-manager
node-type: worker
{{- end }}

{{- define "wazuh.manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wazuh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: manager
app: wazuh-manager
{{- end }}
