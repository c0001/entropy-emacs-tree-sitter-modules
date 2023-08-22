#!/bin/bash

_top_src_name="${BASH_SOURCE[0]}"
while [ -h "$_top_src_name" ]; do # resolve $_top_src_name until the file is no longer a symlink
    _top_src_dir="$( cd -P "$( dirname "$_top_src_name" )" >/dev/null && pwd )"
    _top_src_name="$(readlink "$_top_src_name")"

    # if $_top_src_name was a relative symlink, we need to resolve it relative
    # to the path where the symlink file was located
    [[ $_top_src_name != /* ]] && _top_src_name="$_top_src_dir/$_top_src_name"
done
_top_src_dir="$( cd -P "$( dirname "$_top_src_name" )" >/dev/null && pwd )"

_top_cur_dir="$(pwd)"

set -u
set -e

languages=(
    'bash'
    'c'
    'c-sharp'
    'clojure'
    'cmake'
    'cpp'
    'css'
    'dart'
    'dockerfile'
    'elisp'
    'elixir'
    'glsl'
    'go'
    'go-mod'
    'heex'
    'html'
    'janet-simple'
    'java'
    'javascript'
    'json'
    'julia'
    'kotlin'
    'lua'
    'make'
    'markdown'
    'org'
    'perl'
    'proto'
    'python'
    'php'
    'ruby'
    'rust'
    'scss'
    'souffle'
    'sql'
    'sql-postgre'
    'surface'
    'toml'
    'tsx'
    'typescript'
    'verilog'
    'vhdl'
    'wgsl'
    'yaml'
)

for language in "${languages[@]}"
do
    bash "${_top_src_dir}"/build.sh "${language}"
done
