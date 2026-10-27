{{/*
Platform configuration values, read from the IDT configuration in the icekube namespace.
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
{{- $username := ( include "username" . ) }}
{{- $token := ( include "token" . ) }}
{{- $regurl := ( include "regurl" . ) }}
{{- (printf "{\"auths\": {\"%s\": {\"username\":\"%s\",\"password\":\"%s\",\"auth\": \"%s\"}}}" $regurl $username $token (printf "%s:%s" $username $token | b64enc)) | b64enc }}
{{- end }}

{{/*
Image of one component: <registryUrl>/ds2-eu/mkt-<module.name>/<image name>:<tag>.
Call with (dict "root" $ "name" <component name> "c" <component values>).
*/}}
{{- define "gcat.imageURL" -}}
{{- $img := .c.image | default dict -}}
{{- $regurl := ( include "regurl" .root ) -}}
{{- printf "%s/ds2-eu/mkt-%s/%s:%s" $regurl .root.Values.module.name (required (printf "components.%s.image.name is required" .name) $img.name) (required (printf "components.%s.image.tag is required" .name) $img.tag) -}}
{{- end }}

{{- define "gcat.manualimageURL" -}}
{{- $img := .c.image | default dict -}}
{{- $regurl := ( include "regurl" .root ) -}}
{{- $registryRepository := ( include "registryRepository" .root ) -}}
{{- printf "%s%s%s:%s" $regurl $registryRepository (required (printf "components.%s.image.name is required" .name) $img.name) (required (printf "components.%s.image.tag is required" .name) $img.tag) -}}
{{- end }}

{{/*
Name of the shared image pull secret.
*/}}
{{- define "gcat.pullSecretName" -}}
{{ .Values.module.name }}-imagepullsecret
{{- end }}
