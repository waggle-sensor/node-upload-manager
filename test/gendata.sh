#!/bin/bash

mkitem() {
    mkdir -p $(dirname "${1}") && echo wow > "${1}"
}


mkitem uploads/imagesampler-top/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/data
mkitem uploads/imagesampler-top/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/meta

mkitem uploads/Pluginctl/imagesampler-top/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/data
mkitem uploads/Pluginctl/imagesampler-top/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/meta

mkitem uploads/missing-meta/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/data

mkitem uploads/missing-data/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/meta

mkitem uploads/Pluginctl/missing-meta/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/data

mkitem uploads/Pluginctl/missing-data/0.2.5/1638576647406523064-9801739daae44ec5293d4e1f53d3f4d2d426d91c/meta
