#!/bin/bash
set -eu

find_uploads_in_cwd() {
    find . -mindepth 3 -maxdepth 4 -type d | awk -F/ '
$3 ~ /[0-9]+\.[0-9]+\.[0-9]+/ && $4 ~ /[0-9]+-[0-9a-f]+/
$4 ~ /[0-9]+\.[0-9]+\.[0-9]+/ && $5 ~ /[0-9]+-[0-9a-f]+/
'
}

cd uploads
find_uploads_in_cwd | sort
# Output:
# ./Pluginctl/imagesampler-top/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c
# ./Pluginctl/missing-data/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c
# ./Pluginctl/missing-meta/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c
# ./imagesampler-top/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c
# ./missing-data/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c
# ./missing-meta/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c
