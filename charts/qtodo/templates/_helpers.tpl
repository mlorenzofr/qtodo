{{/*
Expand the name of the chart.
*/}}
{{- define "qtodo.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "qtodo.fullname" -}}
{{- if .Values.global.fullnameOverride }}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.global.nameOverride }}
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
{{- define "qtodo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qtodo.labels" -}}
helm.sh/chart: {{ include "qtodo.chart" . }}
{{ include "qtodo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qtodo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qtodo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
QTodo component labels
*/}}
{{- define "qtodo.qtodoLabels" -}}
{{ include "qtodo.labels" . }}
app.kubernetes.io/component: qtodo
{{- end }}

{{/*
QTodo component selector labels
*/}}
{{- define "qtodo.qtodoSelectorLabels" -}}
{{ include "qtodo.selectorLabels" . }}
app.kubernetes.io/component: qtodo
{{- end }}

{{/*
PostgreSQL component labels
*/}}
{{- define "qtodo.postgresqlLabels" -}}
{{ include "qtodo.labels" . }}
app.kubernetes.io/component: postgresql
{{- end }}

{{/*
PostgreSQL component selector labels
*/}}
{{- define "qtodo.postgresqlSelectorLabels" -}}
{{ include "qtodo.selectorLabels" . }}
app.kubernetes.io/component: postgresql
{{- end }}

{{/*
Create the name of the qtodo service account to use
*/}}
{{- define "qtodo.serviceAccountName" -}}
{{- if .Values.serviceAccount.qtodo.create }}
{{- default (printf "%s-qtodo" (include "qtodo.fullname" .)) .Values.serviceAccount.qtodo.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.qtodo.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the postgresql service account to use
*/}}
{{- define "qtodo.postgresqlServiceAccountName" -}}
{{- if .Values.serviceAccount.postgresql.create }}
{{- default (printf "%s-postgresql" (include "qtodo.fullname" .)) .Values.serviceAccount.postgresql.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.postgresql.name }}
{{- end }}
{{- end }}

{{/*
PostgreSQL service name
*/}}
{{- define "qtodo.postgresql.serviceName" -}}
{{ include "qtodo.fullname" . }}-postgresql
{{- end }}

{{/*
Database connection URL
*/}}
{{- define "qtodo.databaseUrl" -}}
jdbc:postgresql://{{ include "qtodo.postgresql.serviceName" . }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.database.name }}
{{- end }}

{{/*
Create the image path for the passed in image field
*/}}
{{- define "qtodo.images.image" -}}
{{- if eq (substr 0 7 .version) "sha256:" -}}
{{- printf "%s/%s@%s" .registry .repository .version -}}
{{- else -}}
{{- printf "%s/%s:%s" .registry .repository .version -}}
{{- end -}}
{{- end -}}

{{/*
Returns true if the termination is secure (https) and false otherwise
*/}}
{{- define "qtodo.isSecureTermination" }}
{{- if or (eq .Values.route.tls.termination "reencrypt") (eq .Values.route.tls.termination "passthrough") }}
true
{{- end }}
{{- end }}

{{/*
Returns the port the application should list on
*/}}
{{- define "qtodo.app.port" -}}
{{- if include "qtodo.isSecureTermination" . -}}
{{ .Values.qtodo.securePort }}
{{- else -}}
{{ .Values.qtodo.insecurePort }}
{{- end -}}
{{- end -}}