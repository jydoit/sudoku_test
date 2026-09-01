#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
	printf 'Usage: %s <exported iOS project directory>\n' "$0" >&2
	exit 64
fi

export_dir=${1%/}
product_name=$(basename "$export_dir")
project_root=$(dirname "$export_dir")
info_plist="$export_dir/$product_name-Info.plist"
xcode_project="$project_root/$product_name.xcodeproj/project.pbxproj"
old_storyboard="$export_dir/Launch Screen.storyboard"

for required_path in "$info_plist" "$xcode_project"; do
	if [ ! -f "$required_path" ]; then
		printf 'Missing generated iOS file: %s\n' "$required_path" >&2
		exit 66
	fi
done

build_version=$(/usr/bin/awk '/CURRENT_PROJECT_VERSION = / { value = $3; gsub(/;/, "", value); print value; exit }' "$xcode_project")
case "$build_version" in
	''|*[!A-Za-z0-9_-]*)
		printf 'Invalid CURRENT_PROJECT_VERSION in generated Xcode project: %s\n' "$build_version" >&2
		exit 65
		;;
esac
launch_storyboard_name="ColorKingLaunchScreenV$build_version"
new_storyboard="$export_dir/$launch_storyboard_name.storyboard"

if [ -f "$old_storyboard" ]; then
	mv "$old_storyboard" "$new_storyboard"
elif [ ! -f "$new_storyboard" ]; then
	printf 'Missing generated launch storyboard: %s\n' "$old_storyboard" >&2
	exit 66
fi

/usr/libexec/PlistBuddy -c "Set :UILaunchStoryboardName $launch_storyboard_name" "$info_plist"
/usr/bin/perl -0pi -e "s/Launch Screen\\.storyboard/$launch_storyboard_name.storyboard/g" "$xcode_project"

printf 'Prepared iOS launch screen: %s (cache key: %s)\n' "$new_storyboard" "$launch_storyboard_name"
