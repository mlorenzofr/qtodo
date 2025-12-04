CONTAINER_COMMAND = $(shell if [ -x "$(shell which docker)" ];then echo "docker" ; else echo "podman";fi)
TAG := $(or $(TAG),latest)
TAG_SIGNER := $(or $(TAG_SIGNER),signer)
IMAGE := $(or $(IMAGE),localhost/qtodo:$(TAG))
IMAGE_SIGNER := $(or $(IMAGE_SIGNER),localhost/qtodo-signer:$(TAG))
IMAGE_SIGNED := $(or $(IMAGE_SIGNED),localhost/qtodo-signed:$(TAG))
VERSION := $(or $(VERSION),1.0.0-SNAPSHOT)
ARTIFACT := $(or $(ARTIFACT),qtodo-$(VERSION)-runner.jar)
KUBECONFIG := $(or $(KUBECONFIG),$(HOME)/.kube/config)
CONTAINER_AUTH_JSON := $(or $(CONTAINER_AUTH_JSON),$(HOME)/.config/containers/auth.json)
SBOM_PREDICATE := $(or $(SBOM_PREDICATE),qtodo-sbom.json)

COSIGN_SERVER_URL = $(shell oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=client-server -o jsonpath='{.items[0].spec.host}')

export ROOT_DIR = $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
BIN = $(ROOT_DIR)/target
RESOURCES = $(ROOT_DIR)/resources

UNAME_S := $(shell uname -s)
SELINUX_SUFFIX :=
ifeq ($(UNAME_S),Linux)
    SELINUX_SUFFIX := :Z
endif

.PHONY: build build-local download-cosign sign-artifact build-image push attest-sbom clean
build: build-image $(BIN)
	$(CONTAINER_COMMAND) create --name qtodo-build-tmp $(IMAGE)
	$(CONTAINER_COMMAND) cp qtodo-build-tmp:/deployments/$(ARTIFACT) $(BIN)/$(ARTIFACT)
	$(CONTAINER_COMMAND) rm -f qtodo-build-tmp

build-local: clean
	mvn package -Dquarkus.package.jar.type=uber-jar

download-cosign:
	if [ ! -f $(BIN)/cosign-rhtas ]; then \
		curl -sSfk "https://$(COSIGN_SERVER_URL)/clients/linux/cosign-amd64.gz" -o - | gunzip -c > $(BIN)/cosign-rhtas; \
		chmod 755 $(BIN)/cosign-rhtas; \
	fi

download-ec:
	if [ ! -f $(BIN)/ec ]; then \
		curl -sSfk "https://$(COSIGN_SERVER_URL)/clients/linux/ec-amd64.gz" -o - | gunzip -c > $(BIN)/ec-rhtas; \
		chmod 755 $(BIN)/ec-rhtas; \
	fi

sign-artifact: build-signer-image
	$(CONTAINER_COMMAND) run --rm \
		-v $(BIN):/signer$(SELINUX_SUFFIX) \
		-v $(KUBECONFIG):/root/.kube/config$(SELINUX_SUFFIX) \
		$(IMAGE_SIGNER) /usr/local/bin/sign-jar.sh /signer/$(ARTIFACT)

sign-image: build-signer-image
	$(CONTAINER_COMMAND) run --rm \
		-v $(CONTAINER_AUTH_JSON):/root/.config/containers/auth.json$(SELINUX_SUFFIX) \
		-v $(KUBECONFIG):/root/.kube/config$(SELINUX_SUFFIX) \
		-e REGISTRY_AUTH_FILE=/root/.config/containers/auth.json \
		$(IMAGE_SIGNER) /usr/local/bin/sign-image.sh $(IMAGE)

build-image:
	$(CONTAINER_COMMAND) build -t $(IMAGE) -f Containerfile.build

build-signed-image:
	$(CONTAINER_COMMAND) build -t $(IMAGE_SIGNED) -f Containerfile --build-arg artifact=$(ARTIFACT) --build-arg version=$(VERSION)

build-signer-image: download-cosign download-ec
	$(CONTAINER_COMMAND) build -t $(IMAGE_SIGNER) -f Containerfile.signer

push:
	$(CONTAINER_COMMAND) push $(IMAGE)

attest-sbom: build-signer-image
	$(CONTAINER_COMMAND) run --rm \
		-v $(CONTAINER_AUTH_JSON):/root/.docker/config.json$(SELINUX_SUFFIX) \
		-v $(KUBECONFIG):/root/.kube/config$(SELINUX_SUFFIX) \
		-v $(RESOURCES)/$(SBOM_PREDICATE):/signer/$(SBOM_PREDICATE)$(SELINUX_SUFFIX) \
		$(IMAGE_SIGNER) /usr/local/bin/attest-sbom.sh $(IMAGE) /signer/$(SBOM_PREDICATE)

verify-artifact: build-signer-image
	$(CONTAINER_COMMAND) run --rm \
		-v $(BIN):/signer$(SELINUX_SUFFIX) \
		-v $(KUBECONFIG):/root/.kube/config$(SELINUX_SUFFIX) \
		$(IMAGE_SIGNER) /usr/local/bin/verify-artifact.sh /signer/$(ARTIFACT)

verify-sbom: build-signer-image
	$(CONTAINER_COMMAND) run --rm \
		-v $(CONTAINER_AUTH_JSON):/root/.docker/config.json$(SELINUX_SUFFIX) \
		-v $(KUBECONFIG):/root/.kube/config$(SELINUX_SUFFIX) \
		$(IMAGE_SIGNER) /usr/local/bin/verify-sbom.sh $(IMAGE)

$(BIN):
	-mkdir -p $(BIN)

clean:
	rm -rf $(BIN)/*

clean-cosign:
	rm -f $(BIN)/cosign-rhtas

clean-ec:
	rm -f $(BIN)/ec-rhtas