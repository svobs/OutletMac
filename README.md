# OutletMac

## Prerequisites

    sudo gem update --system
    brew update
    brew upgrade
    brew cleanup -d -v
	brew install cocoapods
    # is this required?
    sudo gem install -n /usr/local/bin cocoapods -v 1.8.4

	brew install swift-protobuf
	(see: https://crlacayo.me/2020/01/15/swift-protobuf/)

	pod install
	Afterwards look in: './Pods/gRPC-Swift-Plugins/' for 'protoc-gen-swift' and 'protoc-gen-grpc-swift'

## Updating Pod Dependencies
	pod outdated
	pod update

## TODO
- Add Drag & Drop support to/from Finder, etc.
- Test Drag & Drop of all node types
- need to implement timeout for grpc requests
