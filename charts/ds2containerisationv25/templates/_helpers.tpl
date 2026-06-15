{{/*
Expand the name of the chart.
*/}}
{{- define "containerisationv25.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "containerisationv25.fullname" -}}
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
{{- define "containerisationv25.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "containerisationv25.labels" -}}
helm.sh/chart: {{ include "containerisationv25.chart" . }}
{{ include "containerisationv25.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "containerisationv25.selectorLabels" -}}
app.kubernetes.io/name: {{ include "containerisationv25.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "containerisationv25.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "containerisationv25.fullname" .) .Values.serviceAccount.name }}
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

{{- define "hostURL" -}}
{{- $domain:= ( include "domain" . ) }}
{{- (printf "%s.%s" .Values.app.name $domain) }}
{{- end }}

{{- define "imageURL" -}}
{{- $regurl:= ( include "regurl" . ) }}
{{- (printf "%s/ds2-eu/mkt-%s-%s/%s:%s" $regurl .Values.module.name Values.module.variant .Values.image.name .Values.image.tag) }}
{{- end }}
