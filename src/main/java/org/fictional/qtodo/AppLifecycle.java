package org.fictional.qtodo;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import io.quarkus.runtime.StartupEvent;

@ApplicationScoped
public class AppLifecycle {

    private static final Logger LOG = Logger.getLogger(AppLifecycle.class);

    @ConfigProperty(name = "app.version", defaultValue = "unknown")
    String appVersion;

    @ConfigProperty(name = "app.git-commit", defaultValue = "unknown")
    String gitCommit;

    void onStart(@Observes StartupEvent ev) {
        LOG.infof("qtodo version=%s commit=%s", appVersion, gitCommit);
    }
}
