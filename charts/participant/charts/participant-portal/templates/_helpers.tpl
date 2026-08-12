{{/*
Expand the name of the chart.
*/}}
{{- define "participant-portal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "participant-portal.fullname" -}}
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
Create a shorter fully qualified app name using "-pp" instead of the full chart name.
This prevents hitting the 63-character limit on Kubernetes resources (like volumes).
*/}}
{{- define "participant-portal.truncatedName" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-pp" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Generates a resource name by combining the base name with a suffix, automatically
falling back to the short "-pp-" form when the full name would exceed Kubernetes'
63-character limit. Fails explicitly (instead of silently truncating) if the name
still doesn't fit, to avoid silent name collisions between resources.
Usage: {{ include "participant-portal.resourceName" (dict "context" . "suffix" "-asset-styles-config") }}
*/}}
{{- define "participant-portal.resourceName" -}}
{{- $ctx := .context -}}
{{- $suffix := .suffix -}}
{{- $full := printf "%s%s" (include "participant-portal.fullname" $ctx) $suffix -}}
{{- if le (len $full) 63 -}}
{{- $full -}}
{{- else -}}
{{- $short := printf "%s%s" (include "participant-portal.truncatedName" $ctx) $suffix -}}
{{- if gt (len $short) 63 -}}
{{- if $ctx.Values.fullnameOverride -}}
{{- fail (printf "Resource name %q (%d chars) exceeds 63 characters. fullnameOverride %q + suffix %q is too long. Shorten the fullnameOverride." $short (len $short) $ctx.Values.fullnameOverride $suffix) -}}
{{- else -}}
{{- fail (printf "Resource name %q (%d chars) exceeds 63 characters even with the short form. Shorten the release name %q or the suffix %q." $short (len $short) $ctx.Release.Name $suffix) -}}
{{- end -}}
{{- end -}}
{{- $short -}}
{{- end -}}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "participant-portal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "participant-portal.labels" -}}
helm.sh/chart: {{ include "participant-portal.chart" . }}
{{ include "participant-portal.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "participant-portal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "participant-portal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "participant-portal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "participant-portal.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
