{{/*
Expand the name of the chart.
*/}}
{{- define "ds2connectorv21pae.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ds2connectorv21pae.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "ds2connectorv21pae.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ds2connectorv21pae.labels" -}}
helm.sh/chart: {{ include "ds2connectorv21pae.chart" . }}
{{ include "ds2connectorv21pae.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ds2connectorv21pae.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ds2connectorv21pae.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ds2connectorv21pae.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ds2connectorv21pae.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Added to get the platform configuration values
*/}}
{{- define "regurl" -}}
{{ (lookup "v1" "ConfigMap" "icekube" "idtconfigmap").data.registryUrl }}
{{- end }}

{{- define "username" -}}
{{ ((lookup "v1" "Secret" "icekube" "idtsecret").data.username | b64dec) }}
{{- end }}

{{- define "token" -}}
{{ ((lookup "v1" "Secret" "icekube" "idtsecret").data.token | b64dec) }}
{{- end }}

{{- define "domain" -}}
{{ (lookup "v1" "ConfigMap" "icekube" "idtconfigmap").data.domain }}
{{- end }}

{{- define "registryRepository" -}}
{{ (lookup "v1" "ConfigMap" "icekube" "idtconfigmap").data.registryRepository }}
{{- end }}

{{- define "secret" -}}
{{- $username:=  ( include "username" . ) }}
{{- $token:= ( include "token" . ) }}
{{- $regurl:= ( include "regurl" . ) }}
{{- (printf "{\"auths\": {\"%s\": {\"username\":\"%s\",\"password\":\"%s\",\"auth\": \"%s\"}}}" (printf "%s" $regurl) (printf "%s" $username) (printf "%s" $token) (printf "%s:%s" $username $token | b64enc)) | b64enc }}
{{- end }}

{{- define "ds2identityhubhostURL" -}}
{{- $domain:= ( include "domain" . ) }}
{{- (printf "%s.%s" .Values.ds2identityhub.app.name $domain) }}
{{- end }}

{{- define "ds2identityhubimageURL" -}}
{{- $regurl:= ( include "regurl" . ) }}
{{- $registryRepository:= ( include "registryRepository" . ) }}
{{- (printf "%s%s%s:%s" $regurl $registryRepository .Values.ds2identityhub.image.name .Values.ds2identityhub.image.tag) }}
{{- end }}

{{- define "ds2controlplanehostURL" -}}
{{- $domain:= ( include "domain" . ) }}
{{- (printf "%s.%s" .Values.ds2controlplane.app.name $domain) }}
{{- end }}

{{- define "ds2controlplaneimageURL" -}}
{{- $regurl:= ( include "regurl" . ) }}
{{- $registryRepository:= ( include "registryRepository" . ) }}
{{- (printf "%s%s%s:%s" $regurl $registryRepository .Values.ds2controlplane.image.name .Values.ds2controlplane.image.tag) }}
{{- end }}

{{- define "ds2dataplanehostURL" -}}
{{- $domain:= ( include "domain" . ) }}
{{- (printf "%s.%s" .Values.ds2dataplane.app.name $domain) }}
{{- end }}

{{- define "ds2dataplaneimageURL" -}}
{{- $regurl:= ( include "regurl" . ) }}
{{- $registryRepository:= ( include "registryRepository" . ) }}
{{- (printf "%s%s%s:%s" $regurl $registryRepository .Values.ds2dataplane.image.name .Values.ds2dataplane.image.tag) }}
{{- end }}

{{- define "ds2identityhubdid" -}}
{{- $ds2identityhubhostURL:= ( include "ds2identityhubhostURL" . ) }}
{{- (printf "did:web:%s:%s" $ds2identityhubhostURL .Values.app.organisationId) }}
{{- end }}

