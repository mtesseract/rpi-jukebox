{{- define "init" -}}
  {{- if not .initialized -}}
    {{- $defaultConf := .Files.Get "internal/defaults/00-defaults.yaml" | fromYaml -}}
    {{- $conf := merge .Values $defaultConf -}}
    {{- $_ := set $conf "namespace" .Release.Namespace -}}
	{{- $jukeboxImageRepo := dig "jukebox" "image" "repo" "" $conf -}}
	{{- $jukeboxImageTag := dig "jukebox" "image" "tag" "" $conf -}}
	{{- $jukeboxImageDigest := dig "jukebox" "image" "digest" "" $conf -}}
	{{- $jukeboxImageRef := printf "%s:%s" $jukeboxImageRepo $jukeboxImageTag -}}
	{{- if ne $jukeboxImageDigest "" }}
	  {{- $jukeboxImageRef = printf "%s@%s" $jukeboxImageRepo $jukeboxImageDigest -}}
	{{- end }}
	{{- $_ := set $conf "jukeboxImageRef" $jukeboxImageRef -}}
    {{- $_ := set . "initialized" true -}}
    {{- $_ := set . "conf" $conf -}}
  {{- end -}}
{{- end -}}

{{- define "chartName" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "commonLabels" -}}
helm.sh/chart: {{ include "chartName" . }}
{{ include "selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
