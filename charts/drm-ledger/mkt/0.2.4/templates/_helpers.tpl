{{/*
DRM Ledger Helm Chart - Template Helpers
*/}}

{{/* Chart name */}}
{{- define "drm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Namespace - IDT creates a namespace named after the module and deploys there */}}
{{- define "drm.namespace" -}}
{{- .Release.Namespace }}
{{- end }}

{{/* Domain - the organisation domain configured by the IDT installation */}}
{{- define "drm.domain" -}}
{{- include "domain" . }}
{{- end }}

{{/* Ingress host for the DRM UI: <drmUiFrontend.name>.<domain> */}}
{{- define "drm.uiHost" -}}
{{- printf "%s.%s" .Values.drmUiFrontend.name (include "drm.domain" .) }}
{{- end }}

{{/* Org base path on PV */}}
{{- define "drm.orgBase" -}}
/var/hyperledger/fabric/organizations
{{- end }}

{{/* Common labels */}}
{{- define "drm.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* Ingress class - only rendered if className is non-empty */}}
{{- define "drm.ingressClass" -}}
{{- if .Values.ingress.className }}
ingressClassName: {{ .Values.ingress.className }}
{{- end }}
{{- end }}

{{/*
Registry URL, username and token are provided by the IDT installation:
  ConfigMap icekube/idtconfigmap -> registryUrl (e.g. ghcr.io)
  Secret    icekube/idtsecret    -> username, token (GitHub PAT with read:packages)
*/}}
{{- define "regurl" -}}
{{ (lookup "v1" "ConfigMap" "icekube" "idtconfigmap").data.registryUrl }}
{{- end }}

{{- define "domain" -}}
{{ (lookup "v1" "ConfigMap" "icekube" "idtconfigmap").data.domain }}
{{- end }}

{{- define "username" -}}
{{ ((lookup "v1" "Secret" "icekube" "idtsecret").data.username | b64dec) }}
{{- end }}

{{- define "token" -}}
{{ ((lookup "v1" "Secret" "icekube" "idtsecret").data.token | b64dec) }}
{{- end }}

{{- define "registryRepository" -}}
{{ (lookup "v1" "ConfigMap" "icekube" "idtconfigmap").data.registryRepository }}
{{- end }}

{{/* dockerconfigjson payload for the image pull secret */}}
{{- define "secret" -}}
{{- $username:=  ( include "username" . ) }}
{{- $token:= ( include "token" . ) }}
{{- $regurl:= ( include "regurl" . ) }}
{{- (printf "{\"auths\": {\"%s\": {\"username\":\"%s\",\"password\":\"%s\",\"auth\": \"%s\"}}}" (printf "%s" $regurl) (printf "%s" $username) (printf "%s" $token) (printf "%s:%s" $username $token | b64enc)) | b64enc }}
{{- end }}

{{/*
Marketplace image URL:
  <regurl>/ds2-eu/mkt-<module.name>/<image.name>:<image.tag>
Call with the root context and the image entry, e.g.
  {{ include "drm.imageURL" (dict "ctx" $ "image" $.Values.images.fabricCA) }}
*/}}
{{- define "drm.imageURL" -}}
{{- $ctx := .ctx -}}
{{- $regurl := include "regurl" $ctx -}}
{{- printf "%s/ds2-eu/mkt-%s/%s:%s" $regurl $ctx.Values.module.name .image.name .image.tag }}
{{- end }}

{{- define "drm.manualimageURL" -}}
{{- $ctx := .ctx -}}
{{- $regurl:= include "regurl" $ctx -}}
{{- $registryRepository:= include "registryRepository" $ctx -}}
{{- (printf "%s%s%s:%s" $regurl $registryRepository .image.name .image.tag) }}
{{- end }}

{{/* Single image pull secret shared by every component in the chart */}}
{{- define "drm.imagePullSecretName" -}}
{{- printf "%s-imagepullsecret" .Values.module.name }}
{{- end }}

{{/* imagePullSecrets block - rendered only when the private registry is in use */}}
{{- define "drm.imagePullSecrets" -}}
{{- if .Values.image.privateRegistry.enabled }}
imagePullSecrets:
  - name: {{ include "drm.imagePullSecretName" . }}
{{- end }}
{{- end }}

{{/* Storage class bound to the chart-managed PV for an org (no dynamic provisioning) */}}
{{- define "drm.storageClassName" -}}
{{- printf "%s-fabric-%s-storageclass" .ctx.Release.Namespace .org }}
{{- end }}
