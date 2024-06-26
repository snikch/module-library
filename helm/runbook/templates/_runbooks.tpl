{{/*
Renders a value that contains template perhaps with scope if the scope is present.
Usage:
{{ include "runbook.compile.tpl" ( dict "value" .Values.path.to.the.runbook.spec "context" $ ) }}
If you're using 'include' inside your values.yaml templates, you need to pass the correct context, e.g.
{{- include "runbook.compile.tpl" ( dict "value" .Values.runbook.sentry "context" (dict "Chart" $.Chart "Subcharts" $.Subcharts "Release" $.Release "Template" $.Template "Values" $.Values ) ) }}
Here it's important that you have the 'Template' key in the context, otherwise you'll get an error 
*/}}
{{- define "runbook.compile.tpl" -}}
{{ $runbookName := .value.runbookName }}
{{ $ctx := .context }}
apiVersion: platform.plural.sh/v1alpha1
kind: Runbook
metadata:
  name: {{ $runbookName }}
  labels: {{ include "runbook.tplvalues.render" ( dict "value" .value.labels "context" $ctx) | nindent 4}}
spec:
  name: {{ $runbookName | replace "-" " " | title }}
  description: {{ .value.description }}
  datasources:
  {{- range $componentKey, $componentValue := .value.components }}
  {{- $name := $componentKey }}
  {{- $podRegex := include "runbook.tplvalues.render" ( dict "value" (index $componentValue "prometheus" "podRegexTpl") "context" $ctx) }}
  {{- $resourceName:= include "runbook.tplvalues.render" ( dict "value" (index $componentValue "resourceNameTpl" ) "context" $ctx) }}
  - name: {{ $name }}-cpu
    type: prometheus
    prometheus:
      format: cpu
      legend: $pod
      query: sum(rate(container_cpu_usage_seconds_total{namespace="{{ $ctx.Release.Namespace }}",pod=~"{{ $podRegex }}"}[5m])) by (pod)
  - name: {{ $name }}-memory
    type: prometheus
    prometheus:
      format: memory
      legend: $pod
      query: sum(container_memory_working_set_bytes{namespace="{{ $ctx.Release.Namespace }}",pod=~"{{ $podRegex }}",image!="",container!=""}) by (pod)
  - name: {{ $name }}
    type: kubernetes
    kubernetes:
      resource: {{ index $componentValue "kind" }}
      name: {{ $resourceName }}
  {{- end }}
  actions:
  - name: scale
    action: config
    redirectTo: '/'
    configuration:
      updates:
      {{- range $componentKey, $componentValue := .value.components }}
      {{- $name := $componentKey }}
      {{- $pathList := splitList "." .path }}
      - path: 
      {{- range $path := $pathList }}
        - {{ $path }}
      {{- end }}
        - resources
        - requests
        - cpu
        valueFrom: {{ $name }}-cpu
      - path:
      {{- range $path := $pathList }}
        - {{ $path }}
      {{- end }}
        - resources
        - requests
        - memory
        valueFrom: {{ $name }}-memory
      - path: 
      {{- range $path := $pathList }}
        - {{ $path }}
      {{- end }}
        - resources
        - limits
        - cpu
        valueFrom: {{ $name }}-cpu-limit
      - path:
      {{- range $path := $pathList }}
        - {{ $path }}
      {{- end }}
        - resources
        - limits
        - memory
        valueFrom: {{ $name }}-memory-limit
      {{- end }}
  display: |-
    <root gap='medium'>
      <box pad='small' gap='medium' direction='row' align='center'>
        <button label='Scale' action='scale' primary='true' headline='true' />
      </box>
    {{- range $componentKey, $componentValue := .value.components }}
    {{- $name := $componentKey }}
      <box pad='small' gap='medium' direction='row' align='center'>
        <box direction='row' align='center' gap='small'>
          <box gap='small' align='center'>
            <timeseries datasource="{{ $name }}-cpu" label="{{ $runbookName | replace "-" " " | title }} {{ $name | title }} CPU Usage" />
            <text size='small'>You should set a reservation to 
              roughly correspond to 80% utilization</text>
            <text size='small'>A CPU limit should not be set</text>
          </box>
          <box gap='small' align='center'>
            <timeseries datasource="{{ $name }}-memory" label="{{ $runbookName | replace "-" " " | title }} {{ $name | title }} Memory Usage" />
            <text size='small'>You should set a reservation to 
              roughly correspond to 80% utilization</text>
            <text size='small'>A Memory limit should be set</text>
          </box>
        </box>
        <box gap='small'>
          <box gap='xsmall'>
            <input placeholder="250m" label='{{ $runbookName | replace "-" " " | title }} {{ $name | title }} CPU Request' name='{{ $name }}-cpu'>
              <valueFrom 
                datasource="{{ $name }}"
                doc="kubernetes.raw"
                path="spec.template.spec.containers[0].resources.requests.cpu" />
            </input>
            <input placeholder="1Gi" label='{{ $runbookName | replace "-" " " | title }} {{ $name | title }} Memory Request' name='{{ $name }}-memory'>
              <valueFrom 
                datasource="{{ $name }}"
                doc="kubernetes.raw"
                path="spec.template.spec.containers[0].resources.requests.memory" />
            </input>
          </box>
          <box gap='xsmall'>
            <input placeholder="250m" label='{{ $runbookName | replace "-" " " | title }} {{ $name | title }} CPU Limit' name='{{ $name }}-cpu-limit'>
              <valueFrom
                datasource="{{ $name }}"
                doc="kubernetes.raw"
                path="spec.template.spec.containers[0].resources.limits.cpu" />
            </input>
            <input placeholder="1Gi" label='{{ $runbookName | replace "-" " " | title }} {{ $name | title }} Memory Limit' name='{{ $name }}-memory-limit'>
              <valueFrom
                datasource="{{ $name }}"
                doc="kubernetes.raw"
                path="spec.template.spec.containers[0].resources.limits.memory" />
            </input>
          </box>
        </box>
      </box>
    {{- end }}
    </root>
{{- end -}}
