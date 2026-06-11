{{/*
Expand the name of the chart.
*/}}
{{- define "service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "service.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels (used on every resource).
*/}}
{{- define "service.labels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: zylos-platform
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels (used on pod selectors and Service selectors).
Kept stable across image-tag changes (no `version` label).
*/}}
{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount name. If serviceAccount.create=true and no explicit name,
default to the fullname. If create=false, use the explicit name or fall
back to "default" (the namespace's default SA).
*/}}
{{- define "service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "service.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Container image reference: prefer digest pinning when set, else tag.
*/}}
{{- define "service.image" -}}
{{- if .Values.image.digest -}}
{{- .Values.image.repository }}@{{ .Values.image.digest -}}
{{- else -}}
{{- .Values.image.repository }}:{{ .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{/*
service.version emitted into OTEL_RESOURCE_ATTRIBUTES. Prefers digest
(stripped of `sha256:` prefix, truncated) over tag for reproducibility.
*/}}
{{- define "service.versionAttr" -}}
{{- if .Values.image.digest -}}
{{- .Values.image.digest | replace "sha256:" "" | trunc 12 -}}
{{- else -}}
{{- .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{/*
OTEL_RESOURCE_ATTRIBUTES env value: comma-separated key=value pairs.
Built-ins: service.namespace, deployment.environment, service.version.
extras from .Values.otel.extraResourceAttributes (map of name -> value).
*/}}
{{- define "service.otelResourceAttrs" -}}
{{- $parts := list -}}
{{- $parts = append $parts (printf "service.namespace=zylos") -}}
{{- $parts = append $parts (printf "deployment.environment=%s" .Values.environment) -}}
{{- $parts = append $parts (printf "service.version=%s" (include "service.versionAttr" .)) -}}
{{- range $k, $v := .Values.otel.extraResourceAttributes -}}
{{- $parts = append $parts (printf "%s=%s" $k $v) -}}
{{- end -}}
{{- join "," $parts -}}
{{- end -}}
