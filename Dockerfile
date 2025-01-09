# Build the manager binary
FROM registry.access.redhat.com/ubi9/go-toolset:1.21 AS builder
ARG TARGETOS
ARG TARGETARCH

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY cmd/main.go cmd/main.go
COPY api/ api/
COPY internal/controller/ internal/controller/
COPY internal/kmmmodule/ internal/kmmmodule/

# Build
# the GOARCH has not a default value to allow the binary be built according to the host where the command
# was called. For example, if we call make docker-build in a local env which has the Apple Silicon M1 SO
# the docker BUILDPLATFORM arg will be linux/arm64 when for Apple x86 it will be linux/amd64. Therefore,
# by leaving it empty we can ensure that the container and binary shipped on it will have the same platform.
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -a -o manager cmd/main.go

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.4
ARG VERSION=none
WORKDIR /
COPY --from=builder /opt/app-root/src/manager .
LABEL name="cloud_ai_openshift_operator" \
      maintainer="Qualcomm Innovation Center, Inc." \
      vendor="Qualcomm Innovation Center, Inc." \
      version="${VERSION}" \
      release="${VERSION}" \
      summary="Openshift Operator to orchestrate the Qualcomm AIC containers" \
      description="The Openshift Operator enables the Qualcomm® Cloud AI series of hardware \
on OpenShift clusters by automating the configuration and installation of their \
Linux device drivers and its Kubernetes Device Plugin."
RUN mkdir /licenses
# Include license and location information
LABEL org.opencontainers.image.source https://github.com/quic/cloud-ai-containers
COPY --chmod=755 manual_install/src_img_build/motd.sh /etc
COPY manual_install/src_img_build/CONTAINER_LICENSE.txt /usr/share/doc
RUN ln -s /usr/share/doc/CONTAINER_LICENSE.txt / && \
    ln -s /usr/share/doc/CONTAINER_LICENSE.txt /root && \
    ln -s /usr/share/doc/CONTAINER_LICENSE.txt /licenses && \
# Different systems use different system wide non-login shell config files
    if [ -e /etc/bash.bashrc ]; then \
        echo '[ ! -z "$TERM" -a -r /etc/motd.sh ] && /etc/motd.sh' >> /etc/bash.bashrc ; \
    elif [ -e /etc/bashrc ]; then \
        echo '[ ! -z "$TERM" -a -r /etc/motd.sh ] && /etc/motd.sh' >> /etc/bashrc ; \
    else \
        echo "Unable to find system bashrc" ; \
        exit 1 ; \
    fi

#set user to non-root. UBI images define 65534 as user "nobody"
USER 65534:65534
ENTRYPOINT ["/manager"]
