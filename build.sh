#!/bin/bash

set -e

build_dir="${PWD}/.framework_build"
output_dir="${PWD}/Output"
products_dir="${build_dir}/Build/Products/Release-iphoneos"

rm -rf "${output_dir}"

# TODO: Don't remove build dir unless we want to clean
rm -rf "${build_dir}"
mkdir -p "${build_dir}"

xcodebuild -workspace .swiftpm/xcode/package.xcworkspace \
	-scheme Orion \
	-sdk iphoneos \
	-derivedDataPath "${build_dir}" \
	-configuration Release \
	build \
	ARCHS='$(ARCHS_STANDARD) arm64e'

mkdir -p "${output_dir}/Orion.framework/Modules"
cp -a "${products_dir}/Orion.swiftmodule" "${output_dir}/Orion.framework/Modules/"
libtool -static -o "${output_dir}/Orion.framework/Orion" "${products_dir}/Orion.o"

mkdir -p "${output_dir}/OrionC.framework/Modules"
cp -a Sources/OrionC/include "${output_dir}/OrionC.framework/Headers"
libtool -static -o "${output_dir}/OrionC.framework/OrionC" "${products_dir}/OrionC.o"
cat << EOF > "${output_dir}/OrionC.framework/Modules/module.modulemap"
module OrionC {
    umbrella "Headers"
    export *
}
EOF
