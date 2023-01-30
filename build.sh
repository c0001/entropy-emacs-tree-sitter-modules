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
topdir="$_TREESIT_MK_DIR"

if [ "$(uname)" == "Darwin" ]
then
    soext="dylib"
elif uname | grep -q "MINGW" > /dev/null
then
    soext="dll"
else
    soext="so"
fi

echo "========== Building ${lang} ... =========="

### Retrieve sources

org="tree-sitter"
modules_dir="${topdir}/modules"
repo="tree-sitter-${lang}"
repodir="${modules_dir}/${repo}"
sourcedir="${repodir}/src"
grammardir="$repodir"

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

# We have to go into the source directory to compile, because some
# C files refer to files like "../../common/scanner.h".
cd "${sourcedir}"

### Build

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
    c++ -fPIC -shared *.o -o "libtree-sitter-${lang}.${soext}"
else
    cc -fPIC -shared *.o -o "libtree-sitter-${lang}.${soext}"
fi

### Copy out
echo_job_info "make dist"
mkdir -p "${topdir}/dist"
cp "libtree-sitter-${lang}.${soext}" "${topdir}/dist"
echo_job_info "return to top dir ${topdir}"
cd "${topdir}"
echo "========== Build ${lang} done =========="
