ARG VPP_VERSION=v23.02-rc0-189-gb53439efb
FROM ghcr.io/networkservicemesh/govpp/vpp:${VPP_VERSION} as go
COPY --from=golang:1.20.5-buster /usr/local/go/ /go
ENV PATH ${PATH}:/go/bin
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOBIN=/bin
RUN rm -r /etc/vpp
RUN go install github.com/go-delve/delve/cmd/dlv@v1.8.2
ADD https://github.com/spiffe/spire/releases/download/v1.2.2/spire-1.2.2-linux-x86_64-glibc.tar.gz .
RUN tar xzvf spire-1.2.2-linux-x86_64-glibc.tar.gz -C /bin --strip=2 spire-1.2.2/bin/spire-server spire-1.2.2/bin/spire-agent

FROM go as build
WORKDIR /build
COPY go.mod go.sum ./
COPY ./internal/imports ./internal/imports
RUN go build ./internal/imports
COPY . .
RUN go build -o /bin/cmd-nsc-vpp .

FROM build as test
CMD go test -test.v ./...

FROM test as debug
CMD dlv -l :40000 --headless=true --api-version=2 test -test.v ./...

FROM ghcr.io/networkservicemesh/govpp/vpp:${VPP_VERSION} as runtime
COPY --from=build /bin/cmd-nsc-vpp /bin/cmd-nsc-vpp
ENTRYPOINT [ "/bin/cmd-nsc-vpp" ]
