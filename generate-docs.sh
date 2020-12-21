#!/bin/bash

set -e

if [[ $# = 0 ]]; then
	# Manual mode
	outdir="."
elif [[ $# = 2 ]]; then
	# CI mode
	file_prefix="https://github.com/theos/orion/tree/$1"
	root_url="https://orion.theos.dev/"
	version="$2"
	latest_args=(--module-version "${version}" --github-file-prefix "${file_prefix}" --root-url "${root_url}")
	perma_args=(--module-version "${version}" --github-file-prefix "${file_prefix}" --root-url "${root_url}versions/${version}/")
	outdir=".."
else
	echo "Usage: $0 [<git hash> <version>]"
	exit 1
fi

sourcekitten_path="$(VISUAL=echo gem open jazzy)/bin/sourcekitten"

for module in Orion OrionBackend_{Substrate,Fishhook}; do
  mod_docs="$("${sourcekitten_path}" doc --spm --module-name "${module}")"
  mod_docs="${mod_docs#?}"
  [[ -z "${combined_docs}" ]] || delimiter=","
  combined_docs="${combined_docs}${delimiter}${mod_docs%?}"
done
combined_docs="[${combined_docs}]"

jazzy "${latest_args[@]}" --sourcekitten-sourcefile <(printf '%s' "${combined_docs}") -o "${outdir}/docs"

if [[ $# = 2 ]]; then
	jazzy "${perma_args[@]}" --sourcekitten-sourcefile <(printf '%s' "${combined_docs}") -o "${outdir}/docs-perm"
fi
