ifndef GOPATH
$(warning You need to set up a GOPATH. Run "go help gopath".)
endif

version:=$(cat VERSION)
pkg_name:=claudia
git:=$(strip $(shell which git 2> /dev/null))
go:=$(strip $(shell which go 2> /dev/null))
builder_image:=claudia-builder
claudia_path:=/root/go/src/github.com/wwsean08/claudia

ifneq ($(go),)
		packages:=$(shell $(go) list ./... | grep -v /vendor/)
endif

ifeq ($(GOOS),)
		GOOS:=linux
endif

ifeq ($(GOARCH),)
		GOARCH:=amd64
endif


repo_branch:=$(subst refs/heads/,,$(shell $(git) symbolic-ref HEAD 2> /dev/null))
repo_branch:=$(subst /,-,$(repo_branch))

.PHONY: build builder docs static clean format run cov test vendor

default: build

build:
		docker run --rm -v ${CURDIR}:$(claudia_path) $(builder_image) $(claudia_path)/build.sh

builder:
		docker build -t claudia-builder -f Dockerfile-builder .

static:
		docker run --rm -e VERSION=$(version) -v ${CURDIR}:/src $(builder_image) /src/ui/build.sh

docs:
		docker run --rm -v ${CURDIR}:/src --workdir /src $(builder_image) mkdocs build

image:
		docker build -t claudia .

clean:
		rm -rf bin dist

format:
		$(go) fmt $(packages)

run: build
		./bin/linux_amd64/$(pkg_name) -c etc/config-default.yaml

test: format
		$(go) vet $(packages)
		$(go) test -race -cover $(packages)

cov:
		echo "mode: set" > coverage-all.out
		$(foreach pkg,$(packages),\
				go test -coverprofile=coverage.out $(pkg);\
				tail -n +2 coverage.out >> coverage-all.out;)
		go tool cover -func=coverage-all.out

vendor:
		rm -rf vendor
		dep ensure