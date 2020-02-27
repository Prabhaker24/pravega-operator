#
# Copyright (c) 2017 Dell Inc., or its subsidiaries. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
ARG GO_VERSION=1.13.4
ARG ALPINE_VERSION=3.10

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} as go-builder

ARG PROJECT_NAME=pravega-operator
ARG REPO_PATH=github.com/pravega/${PROJECT_NAME}
ARG BUILD_PATH=${REPO_PATH}/cmd/manager

# Build version and commit SHA should be passed in when performing docker build
ARG VERSION=0.0.0-localdev
ARG GIT_SHA=0000000

WORKDIR /src

COPY pkg ./pkg
COPY cmd ./cmd
COPY go.mod go.sum ./

# Download all dependencies. Dependencies will be cached if the go.mod and go.sum files are not changed
RUN go mod download

RUN  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o /src/${PROJECT_NAME} \
    -ldflags "-X ${REPO_PATH}/pkg/version.Version=${VERSION} -X ${REPO_PATH}/pkg/version.GitSHA=${GIT_SHA}" \
    /src/cmd/manager

# =============================================================================
FROM alpine:${ALPINE_VERSION} AS final

RUN apk add --update \
    sudo \
    libcap

ARG PROJECT_NAME=pravega-operator

COPY --from=go-builder /src/${PROJECT_NAME} /usr/local/bin/${PROJECT_NAME}

RUN sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/${PROJECT_NAME}

RUN adduser -D ${PROJECT_NAME}
USER ${PROJECT_NAME}

ENTRYPOINT ["/usr/local/bin/pravega-operator"]
