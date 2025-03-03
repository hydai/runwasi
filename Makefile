PREFIX ?= /usr/local
INSTALL ?= install
TEST_IMG_NAME ?= wasmtest:latest
HYPER_DIRS = $(shell find demo/wasmedge_hyper_demo -type d)
HYPER_FILES = $(shell find demo/wasmedge_hyper_demo -type f -name '*')
HYPER_IMG_NAME ?= hyper-demo:latest
REQWEST_DIRS = $(shell find demo/wasmedge_reqwest_demo -type d)
REQWEST_FILES = $(shell find demo/wasmedge_reqwest_demo -type f -name '*')
REQWEST_IMG_NAME ?= reqwest-demo:latest
DB_DIRS = $(shell find demo/wasmedge-db-examples -type d)
DB_FILES = $(shell find demo/wasmedge-db-examples -type f -name '*')
DB_IMG_NAME ?= db-demo:latest
MICROSERVICE_DB_DIRS = $(shell find demo/microservice-rust-mysql -type d)
MICROSERVICE_DB_FILES = $(shell find demo/microservice-rust-mysql -type f -name '*')
MICROSERVICE_DB_IMG_NAME ?= microservice-db-demo:latest
export CONTAINERD_NAMESPACE ?= default

TARGET ?= debug
RELEASE_FLAG :=
ifeq ($(TARGET),release)
RELEASE_FLAG = --release
endif

.PHONY: build
build:
	cargo build $(RELEASE_FLAG)

.PHONY: install
install:
	$(INSTALL) target/$(TARGET)/containerd-shim-wasmedge-v1 $(PREFIX)/bin
	$(INSTALL) target/$(TARGET)/containerd-shim-wasmedged-v1 $(PREFIX)/bin
	$(INSTALL) target/$(TARGET)/containerd-wasmedged $(PREFIX)/bin

# TODO: build this manually instead of requiring buildx
test/out/img.tar: test/image/Dockerfile test/image/src/main.rs test/image/Cargo.toml test/image/Cargo.lock
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(TEST_IMG_NAME) ./test/image

load: test/out/img.tar
	sudo ctr -n $(CONTAINERD_NAMESPACE) image import $<

demo/out/hyper_img.tar: demo/images/hyper.Dockerfile \
	$(HYPER_DIRS) $(HYPER_FILES) $(TOKIO_DIRS) $(TOKIO_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(HYPER_IMG_NAME) -f ./demo/images/hyper.Dockerfile ./demo

demo/out/reqwest_img.tar: demo/images/reqwest.Dockerfile \
	$(REQWEST_DIRS) $(REQWEST_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(REQWEST_IMG_NAME) -f ./demo/images/reqwest.Dockerfile ./demo

demo/out/db_img.tar: demo/images/db.Dockerfile \
	$(DB_DIRS) $(DB_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(DB_IMG_NAME) -f ./demo/images/db.Dockerfile ./demo

demo/out/microservice_db_img.tar: demo/images/microservice_db.Dockerfile \
	$(MICROSERVICE_DB_DIRS) $(MICROSERVICE_DB_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(MICROSERVICE_DB_IMG_NAME) -f ./demo/images/microservice_db.Dockerfile ./demo

load_demo: demo/out/hyper_img.tar \
	demo/out/db_img.tar \
	demo/out/reqwest_img.tar \
	demo/out/microservice_db_img.tar
	$(foreach var,$^,\
		sudo ctr -n $(CONTAINERD_NAMESPACE) image import $(var);\
	)

