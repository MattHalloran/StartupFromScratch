{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "vrooli.name" -}}
{{- $name := "" -}}
{{- if and .Values .Values.nameOverride -}}
{{- $name = .Values.nameOverride -}}
{{- else -}}
{{- $name = .Chart.Name -}}
{{- end -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If fullnameOverride is provided, that value is used. Otherwise, the name is generated using RELEASE-NAME-vrooli.name.
*/}}
{{- define "vrooli.fullname" -}}
{{- if and .Values (hasKey .Values "fullnameOverride") .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "vrooli.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "vrooli.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "vrooli.labels" -}}
helm.sh/chart: {{ include "vrooli.chart" . }}
{{ include "vrooli.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "vrooli.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vrooli.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}} 