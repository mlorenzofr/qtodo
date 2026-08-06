# qtodo

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for QTodo - A Quarkus-based todo application with PostgreSQL

**Homepage:** <https://github.com/validatedpatterns/qtodo>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Zero Trust Validated Patterns Team | <ztvp-arch-group@redhat.com> |  |

## Source Code

* <https://github.com/validatedpatterns/qtodo>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.fullnameOverride | string | `""` |  |
| global.nameOverride | string | `""` |  |
| oidc.applicationType | string | `"web-app"` |  |
| oidc.authServerUrl | string | `"https://localhost:8443/realms/qtodo"` |  |
| oidc.clientId | string | `"qtodo"` |  |
| oidc.enabled | bool | `false` |  |
| postgresql.affinity | object | `{}` |  |
| postgresql.database.name | string | `"tasks"` |  |
| postgresql.database.password | string | `"RedH@tPassw0rd"` | # WARNING: For local testing only. Use External Secrets Operator in production. |
| postgresql.database.user | string | `"qtodo_user"` |  |
| postgresql.image.pullPolicy | string | `"IfNotPresent"` |  |
| postgresql.image.registry | string | `"registry.redhat.io"` |  |
| postgresql.image.repository | string | `"rhel8/postgresql-16"` |  |
| postgresql.image.version | string | `"latest"` |  |
| postgresql.livenessProbe.exec.command[0] | string | `"/bin/bash"` |  |
| postgresql.livenessProbe.exec.command[1] | string | `"-c"` |  |
| postgresql.livenessProbe.exec.command[2] | string | `"pg_isready -U ${POSTGRESQL_USER} -d ${POSTGRESQL_DATABASE} -h localhost"` |  |
| postgresql.livenessProbe.failureThreshold | int | `3` |  |
| postgresql.livenessProbe.initialDelaySeconds | int | `30` |  |
| postgresql.livenessProbe.periodSeconds | int | `10` |  |
| postgresql.livenessProbe.timeoutSeconds | int | `5` |  |
| postgresql.nodeSelector | object | `{}` |  |
| postgresql.persistence.accessMode | string | `"ReadWriteOnce"` |  |
| postgresql.persistence.mountPath | string | `"/var/lib/pgsql/data"` |  |
| postgresql.persistence.size | string | `"2Gi"` |  |
| postgresql.persistence.storageClass | string | `""` |  |
| postgresql.podAnnotations | object | `{}` |  |
| postgresql.readinessProbe.exec.command[0] | string | `"/bin/bash"` |  |
| postgresql.readinessProbe.exec.command[1] | string | `"-c"` |  |
| postgresql.readinessProbe.exec.command[2] | string | `"pg_isready -U ${POSTGRESQL_USER} -d ${POSTGRESQL_DATABASE} -h localhost"` |  |
| postgresql.readinessProbe.failureThreshold | int | `3` |  |
| postgresql.readinessProbe.initialDelaySeconds | int | `10` |  |
| postgresql.readinessProbe.periodSeconds | int | `5` |  |
| postgresql.readinessProbe.timeoutSeconds | int | `3` |  |
| postgresql.resources.limits.cpu | string | `"500m"` |  |
| postgresql.resources.limits.memory | string | `"512Mi"` |  |
| postgresql.resources.requests.cpu | string | `"100m"` |  |
| postgresql.resources.requests.memory | string | `"256Mi"` |  |
| postgresql.service.port | int | `5432` |  |
| postgresql.service.targetPort | int | `5432` |  |
| postgresql.service.type | string | `"ClusterIP"` |  |
| postgresql.tolerations | list | `[]` |  |
| qtodo.affinity | object | `{}` |  |
| qtodo.env.JAVA_OPTS | string | `"-XX:+UseContainerSupport -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+UseStringDeduplication"` |  |
| qtodo.env.JAVA_OPTS_APPEND | string | `"-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"` |  |
| qtodo.image.pullPolicy | string | `"IfNotPresent"` |  |
| qtodo.image.registry | string | `"quay.io"` |  |
| qtodo.image.repository | string | `"validatedpatterns/qtodo"` |  |
| qtodo.image.version | string | `"latest"` |  |
| qtodo.initContainers.enabled | bool | `true` |  |
| qtodo.insecurePort | int | `8080` |  |
| qtodo.livenessProbe.failureThreshold | int | `3` |  |
| qtodo.livenessProbe.initialDelaySeconds | int | `30` |  |
| qtodo.livenessProbe.periodSeconds | int | `10` |  |
| qtodo.livenessProbe.tcpSocket.port | string | `"{{ include \"qtodo.app.port\" . }}"` |  |
| qtodo.livenessProbe.timeoutSeconds | int | `5` |  |
| qtodo.nodeSelector | object | `{}` |  |
| qtodo.podAnnotations | object | `{}` |  |
| qtodo.readinessProbe.failureThreshold | int | `3` |  |
| qtodo.readinessProbe.initialDelaySeconds | int | `10` |  |
| qtodo.readinessProbe.periodSeconds | int | `5` |  |
| qtodo.readinessProbe.tcpSocket.port | string | `"{{ include \"qtodo.app.port\" . }}"` |  |
| qtodo.readinessProbe.timeoutSeconds | int | `3` |  |
| qtodo.replicaCount | int | `1` |  |
| qtodo.resources.limits.cpu | string | `"500m"` |  |
| qtodo.resources.limits.memory | string | `"512Mi"` |  |
| qtodo.resources.requests.cpu | string | `"100m"` |  |
| qtodo.resources.requests.memory | string | `"256Mi"` |  |
| qtodo.securePort | int | `8443` |  |
| qtodo.tls.secret | string | `"qtodo-certs"` |  |
| qtodo.tls.serviceServing | bool | `true` |  |
| qtodo.tolerations | list | `[]` |  |
| route.enabled | bool | `true` |  |
| route.host | string | `""` | Automatically generated if not specified. If you want to use a custom route, specify the host name here (e.g. qtodo.apps.example.com) |
| route.path | string | `"/"` |  |
| route.tls.enabled | bool | `true` |  |
| route.tls.insecureEdgeTerminationPolicy | string | `"Redirect"` |  |
| route.tls.termination | string | `"reencrypt"` |  |
| serviceAccount.postgresql.annotations | object | `{}` |  |
| serviceAccount.postgresql.create | bool | `true` |  |
| serviceAccount.postgresql.name | string | `""` |  |
| serviceAccount.qtodo.annotations | object | `{}` |  |
| serviceAccount.qtodo.create | bool | `true` |  |
| serviceAccount.qtodo.name | string | `""` |  |

