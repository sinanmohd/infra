{{- define "kafkaAuth" -}}
authentication:
  type: "scram-sha-512"
  password:
    valueFrom:
      secretKeyRef:
        name: kafka-user-{{ . }}
        key: password
{{- end -}}
