#!/bin/bash
### FL Script Header V2 ##################
set -e
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir/zz_lib"
ast_dir="$scpt_dir/zz_assets"
source "$lib_dir/common.sh" || exit 255
cd "$(dirname "$0")"/../ || exit 42
##########################################

rm -fr "Carthage/Build"
XCODE_XCCONFIG_FILE="$(pwd)/Xcode Supporting Files/StaticCarthageBuild.xcconfig" carthage bootstrap --use-ssh --platform macOS "$@"

"$scpt_dir"/carthage_workaround_static_folder.sh "Static"
