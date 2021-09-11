#!/bin/bash
PY_PKG='outlet/backend/agent/grpc/generated'
PROTO_PATH="./$PY_PKG"
OUT_DIR='../OutletMac/Backend/Generated'

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
REL_PATH=../Pods/gRPC-Swift-Plugins/bin
PROTOC_EXE=protoc-gen-swift
PROTOC_GRPC_EXE=protoc-gen-grpc-swift
GRPC_COMPILE="$SCRIPT_DIR/$REL_PATH/$PROTOC_GRPC_EXE"
PROTO_COMPILE="$SCRIPT_DIR/$REL_PATH/$PROTOC_EXE"

export PATH=$PATH:$GRPC_COMPILE:$PROTO_COMPILE

sed -i -e 's/.*PYTHON.*/import public "Node.proto"; \/\/ Swift/' "$PROTO_PATH/Outlet.proto"

mkdir -p $OUT_DIR

protoc \
	"$PROTO_PATH/Outlet.proto" \
	"$PROTO_PATH/Node.proto" \
	--plugin=$PROTOC_COMPILE \
	--swift_opt=Visibility=Public \
	--swift_out="$OUT_DIR" \
	--proto_path="$PROTO_PATH" \
	--plugin=$GRPC_COMPILE \
	--grpc-swift_opt=Visibility=Public \
	--grpc-swift_out="$OUT_DIR"
