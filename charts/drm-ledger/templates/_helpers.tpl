{{/*
DRM Ledger Helm Chart - Template Helpers
*/}}

{{/* Chart name */}}
{{- define "drm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Namespace */}}
{{- define "drm.namespace" -}}
{{- .Values.global.namespace }}
{{- end }}

{{/* Domain */}}
{{- define "drm.domain" -}}
{{- .Values.global.domain }}
{{- end }}

{{/* Common labels */}}
{{- define "drm.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* Org base path on PV */}}
{{- define "drm.orgBase" -}}
/var/hyperledger/fabric/organizations
{{- end }}

{{/* Ingress class - only rendered if className is non-empty */}}
{{- define "drm.ingressClass" -}}
{{- if .Values.ingress.className }}
ingressClassName: {{ .Values.ingress.className }}
{{- end }}
{{- end }}
