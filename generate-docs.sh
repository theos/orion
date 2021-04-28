#!/bin/bash

set -e

root_url="https://orion.theos.dev/"

if [[ $# = 0 || ($# = 1 && ($1 = "cached" || $1 = "watch")) ]]; then
	# Manual mode
	outdir="."
	# While the Install in Dash button doesn't function correctly locally,
	# we still want it there so that we can edit the CSS properly.
	latest_args=(--module-version "staging" --root-url "${root_url}")
elif [[ $# = 2 ]]; then
	# CI mode
	file_prefix="https://github.com/theos/orion/tree/$1"
	version="$2"
	latest_args=(--module-version "latest (${version})" --github-file-prefix "${file_prefix}" --root-url "${root_url}")
	perma_args=(--module-version "${version}" --github-file-prefix "${file_prefix}" --root-url "${root_url}versions/${version}/")
	outdir=".."
else
	echo "Usage: $0 [watch|cached|<<git hash> <version>>]" >&2
	exit 1
fi
common_args=(--head "$(cat head.html)" --separate-global-declarations --sourcekitten-sourcefile docs.json)

rm -rf "${outdir}/docs" "${outdir}/docs-perm"

# if it's a cached build, use the existing docs.json
if [[ $# = 1 && $1 = "cached" ]]; then
	if [[ ! -r docs.json ]]; then
		echo "Error: You cannot perform a cached build without having normally generated the docs at least once." >&2
		exit 1
	fi
else
	sourcekitten_path="$(VISUAL=echo gem open jazzy)/bin/sourcekitten"

	for module in Orion OrionBackend_{Substrate,Fishhook}; do
	  mod_docs="$("${sourcekitten_path}" doc --spm --module-name "${module}")"
	  mod_docs="${mod_docs#?}"
	  combined_docs="${combined_docs}${mod_docs%?},"
	done
	combined_docs="[${combined_docs%?}]"

	printf '%s' "${combined_docs}" > docs.json
fi

jazzy "${latest_args[@]}" "${common_args[@]}" -o "${outdir}/docs"
cp -a assets "${outdir}/docs/assets"

if [[ $# = 2 ]]; then
	jazzy "${perma_args[@]}" "${common_args[@]}" -o "${outdir}/docs-perm"
fi

if [[ $# = 1 && $1 = "watch" ]]; then
	php -S 0.0.0.0:8080 -t docs &
	fswatch -o README.md -o Guides -o head.html -o .jazzy.yaml -o assets \
		| xargs -n1 -I{} "$0" cached
fi
