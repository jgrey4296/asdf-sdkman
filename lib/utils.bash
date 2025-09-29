#!/usr/bin/env bash

# asdf env vars:
# ASDF_INSTALL_TYPE : version or ref
# ASDF_INSTALL_VERSION : full version number or git ref
# ASDF_INSTALL_PATH : where the tool should be
# ASDF_CONCURRENCY : number of cores
# ASDF_DOWNLOAD_PATH : where bin/download downloads to
# ASDF_PLUGIN_PATH : where the plugin is installed
# ASDF_PLUGIN_SOURCE_URL : url of the plugin
# ASDF_PLUGIN_PREV_REF : previous git-ref of plugin
# ASDF_PLUGIN_POST_REF : updated git-ref of plugin
# ASDF_CMD_FILE : full path of file being sourced

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for <YOUR TOOL>.
GH_REPO="https://github.com/jgrey4296/asdf-sdkman.git"
TOOL_NAME="sdkman"
TOOL_TEST="sdkman-init.sh"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if <YOUR TOOL> is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

function sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

function list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

function list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if <YOUR TOOL> has other means of determining installable versions.
	echo "8.0.20"
}

function download_release() {
	local version filename url
	version="$1"
	filename="$2"

	url="https://get.sdkman.io"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

function install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		export SDKMAN_DIR="$install_path" && "$install_path/$TOOL_NAME-$ASDF_INSTALL_VERSION.sh"


		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
