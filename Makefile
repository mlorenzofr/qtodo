CONTAINER_COMMAND = $(shell if [ -x "$(shell which docker)" ];then echo "docker" ; else echo "podman";fi)
TAG := $(or $(TAG),latest)
IMAGE := $(or $(IMAGE),localhost/qtodo:$(TAG))
SETTINGS := $(or $(SETTINGS),settings.xml)
VERSION := $(or $(VERSION),$(shell grep -oPm1 '(?<=<version>).+?(?=</version>)' pom.xml))
ARTIFACT := $(or $(ARTIFACT),qtodo-$(VERSION)-runner.jar)


.PHONY: build build-image build-custom-image version clean
build:
	./mvnw -s $(SETTINGS) dependency:go-offline
	./mvnw -s $(SETTINGS) package -DskipTests -Dquarkus.package.jar.type=uber-jar

build-image:
	$(CONTAINER_COMMAND) build -t $(IMAGE) -f Containerfile.build --build-arg settings=$(SETTINGS)

build-image-binary:
	$(CONTAINER_COMMAND) build -t $(IMAGE) -f Containerfile --build-arg artifact=$(ARTIFACT) --build-arg version=$(VERSION)

version:
	./mvnw -s $(SETTINGS) help:evaluate -Dexpression=project.version -q -DforceStdout

clean:
	rm -rf target/*
