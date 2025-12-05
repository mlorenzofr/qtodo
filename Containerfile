FROM registry.access.redhat.com/ubi10/ubi-minimal:10.0-1754585875

ARG version=1.0.0
ARG artifact=qtodo-$version-runner.jar

# Maintainer information
LABEL maintainer="Zero Trust Validated Patterns Team <ztvp-arch-group@redhat.com>" \
      description="QTodo - Persistent Web Todo Application" \
      version="$version" \
      io.openshift.tags="quarkus,java,web,pattern" \
      io.openshift.expose-services="8080:http" \
      io.k8s.description="Persistent Web Todo application built with Quarkus" \
      io.k8s.display-name="Quarkus Todo" \
      BASE_IMAGE="registry.access.redhat.com/ubi10/ubi-minimal:10.0-1754585875" \
      JAVA_VERSION="21"

ENV LANGUAGE='en_US:en'

USER root

RUN microdnf install -y --nodocs java-21-openjdk-headless  shadow-utils \
    && microdnf clean all  \
    && echo "securerandom.source=file:/dev/urandom" >> /etc/alternatives/jre/lib/security/java.security
# Create application user and group
RUN groupadd -r quarkus -g 777 && useradd -u 1001 -r -g quarkus -m -d /home/quarkus -s /sbin/nologin quarkus

# Create deployment directory
RUN mkdir -p /deployments && chown -R quarkus:quarkus /deployments

# Set working directory
WORKDIR /deployments
# Copy Quarkus uber jar with proper ownership
COPY --chown=quarkus:quarkus target/$artifact ./


# Set proper permissions
RUN chmod 755 /deployments && \
    find /deployments -type f -exec chmod 644 {} \; && \
    find /deployments -type d -exec chmod 755 {} \;

# Expose application port
EXPOSE 8080

# Switch to non-root user
USER quarkus

# Set JVM options for containerized environments (Pulled production settings from Quarkus documentation)
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+UseStringDeduplication" \
    JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager" \
    JAVA_APP_JAR="/deployments/$artifact" \
    JAVA_DEBUG_PORT="*:5005"

#    Define entrypoint and default command
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS $JAVA_OPTS_APPEND -jar $JAVA_APP_JAR"]
