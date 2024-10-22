{{- define "init" -}}
  {{- if not .initialized -}}
    {{- $conf := .Files.Get "internal/defaults/00-defaults.yaml" | fromYaml -}}
    {{- $_ := set $conf "namespace" .Release.Namespace -}}
    {{- $_ := set . "conf" (merge $conf .Values) -}}
	{{- $jukeboxImageRepo := dig "jukebox" "image" "repo" "" $conf -}}
	{{- $jukeboxImageTag := dig "jukebox" "image" "tag" "" $conf -}}
	{{- $jukeboxImageDigest := dig "jukebox" "image" "digest" "" $conf -}}
	{{- $jukeboxImageRef := printf "%s:%s" $jukeboxImageRepo $jukeboxImageTag -}}
	{{- if ne $jukeboxImageDigest "" }}
	  {{- $jukeboxImageRef = printf "%s@%s" $jukeboxImageRepo $jukeboxImageDigest -}}
	{{- end }}
	{{- $_ := set $conf "jukeboxImageRef" $jukeboxImageRef -}}
    {{- $_ := set . "initialized" true -}}
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
