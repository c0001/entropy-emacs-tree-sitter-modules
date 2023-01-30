#!/bin/bash

_TREESIT_MK_SRC_NAME="${BASH_SOURCE[0]}"
while [ -h "$_TREESIT_MK_SRC_NAME" ]; do # resolve $_TREESIT_MK_SRC_NAME until the file is no longer a symlink
    _TREESIT_MK_DIR="$( cd -P "$( dirname "$_TREESIT_MK_SRC_NAME" )" >/dev/null && pwd )"
    _TREESIT_MK_SRC_NAME="$(readlink "$_TREESIT_MK_SRC_NAME")"

    # if $_TREESIT_MK_SRC_NAME was a relative symlink, we need to resolve it relative
    # to the path where the symlink file was located
    [[ $_TREESIT_MK_SRC_NAME != /* ]] && _TREESIT_MK_SRC_NAME="$_TREESIT_MK_DIR/$_TREESIT_MK_SRC_NAME"
done
_TREESIT_MK_DIR="$( cd -P "$( dirname "$_TREESIT_MK_SRC_NAME" )" >/dev/null && pwd )"

_TREESIT_MK_PWD="$(pwd)"

set -u
set -e

lang="$1"
lang_abbrev_name="$lang"
topdir="$_TREESIT_MK_DIR"
declare soext
if [ "$(uname)" == "Darwin" ]
then
    soext="dylib"
elif uname | grep -q "MINGW" > /dev/null
then
    soext="dll"
else
    soext="so"
fi

declare platform='${uname}'
platform="$(uname)"
if [ "$platform" = Linux ]
then
    platform=linux
elif [ "$platform" = Darwin ]
then
    platform=macos
elif cat "$platform" | grep -q "MINGW" > /dev/null
then
    platform=windows
fi
treesit_cli_curl_url="https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-${platform}-x64.gz"
treesit_cli_dir="${topdir}"/treesit-cli
treesit_cli_bin="${treesit_cli_dir}"/tree-sitter
if [ ! -f "$treesit_cli_bin" ]
then
    echo  "========== Install tree-sitter cli tool =========="
    mkdir -p "$treesit_cli_dir"
    curl -Ls "$treesit_cli_curl_url" | gzip -cd > "$treesit_cli_bin"
    chmod +x "$treesit_cli_bin"
fi

echo "========== Building ${lang} ... =========="

# * Retrieve sources

org="tree-sitter"
modules_dir="${topdir}/modules"
repo="tree-sitter-${lang}"
repodir="${modules_dir}/${repo}"
sourcedir="${repodir}/src"
grammardir="$repodir"

if [ ! -d "$modules_dir" ]; then
    mkdir -p "$modules_dir"
fi

function echo_job_info ()
{
    echo "--> [$repo] $1 ..."
}

case "${lang}" in
    "dockerfile")
        org="camdencheek"
        ;;
    "cmake")
        org="uyha"
        ;;
    "typescript")
        sourcedir="${repodir}/typescript/src"
        grammardir="${repodir}/typescript"
        ;;
    "tsx")
        repo="tree-sitter-typescript"
        repodir="${modules_dir}/${repo}"
        sourcedir="${repodir}/tsx/src"
        grammardir="${repodir}/tsx"
        ;;
    "elixir")
        org="elixir-lang"
        ;;
    "heex")
        org="phoenixframework"
        ;;
    "glsl")
        org="theHamsta"
        ;;
    "go-mod")
        org="camdencheek"
        lang_abbrev_name="gomod"
        ;;
    "make")
        org="alemuller"
        ;;
    "markdown")
        org="ikatyang"
        ;;
    "org")
        org="milisims"
        ;;
    "perl")
        org="ganezdragon"
        ;;
    "proto")
        org="mitchellh"
        ;;
    "sql")
        org="m-novikov"
        ;;
    "toml")
        org="ikatyang"
        ;;
    "vhdl")
        org="alemuller"
        ;;
    "wgsl")
        org="mehmetoguzderin"
        ;;
    "yaml")
        org="ikatyang"
        ;;
esac

if [ ! -e "$repodir" ]; then
    echo_job_info "clone module"
    git clone "https://github.com/${org}/${repo}.git" \
        --depth 1 --quiet "$repodir"
else
    cd "$repodir"
    echo_job_info "clean module project"
    git clean -xfd .
    echo_job_info "git update module project"
    git pull --rebase
fi
if [ ! -e "${grammardir}"/grammar.js ]; then
    echo_job_info "copy grammemr.js to src"
    cp -v "${grammardir}"/grammar.js "${sourcedir}/"
fi

# * PREPARATION
case "$lang" in
    sql)
        cd "${repodir}"
        echo_job_info "generating source"
        "$treesit_cli_bin" generate
        ;;
    *)
        :
        ;;
esac

# * Build
# We have to go into the source directory to compile, because some
# C files refer to files like "../../common/scanner.h".
cd "${sourcedir}"

cc -fPIC -c -I. parser.c
# Compile scanner.c.
if test -f scanner.c
then
    echo_job_info "build scanner"
    cc -fPIC -c -I. scanner.c
fi
# Compile scanner.cc.
if test -f scanner.cc
then
    echo_job_info "build scanner cpp ver."
    c++ -fPIC -I. -c scanner.cc
fi
# Link.
echo_job_info "linkage module with system libs"
if test -f scanner.cc
then
    c++ -fPIC -shared *.o -o "libtree-sitter-${lang_abbrev_name}.${soext}"
else
    cc -fPIC -shared *.o -o "libtree-sitter-${lang_abbrev_name}.${soext}"
fi

### Copy out
declare dist_fname="libtree-sitter-${lang_abbrev_name}.${soext}"
declare dist_dest="${topdir}/dist/${dist_fname}"
echo_job_info "make dist"
mkdir -p "${topdir}/dist"
if [ -f "${dist_dest}" ]
then
    rm -v "${dist_dest}"
fi
cp -v ./"$dist_fname" "$dist_dest"
echo_job_info "return to top dir ${topdir}"
cd "${topdir}"
echo "========== Build ${lang} done =========="
