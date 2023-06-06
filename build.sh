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
branch=''

if [ ! -d "$modules_dir" ]; then
    mkdir -p "$modules_dir"
fi

function echo_job_info ()
{
    echo "--> [$repo] $1 ..."
}

case "${lang}" in
    "cmake")
        org="uyha"
        ;;
    "dart")
        org="ast-grep"
        ;;
    "dockerfile")
        org="camdencheek"
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
    "elisp")
        org="Wilfred"
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
    "surface")
        org="connorlay"
        ;;
    "sql")
        org="DerekStride"
        branch="gh-pages"
        ;;
    "sql-postgre")
        org="m-novikov"
        lang_abbrev_name="postgre-sql"
        repo="tree-sitter-sql"
        repodir="${modules_dir}/${repo}-postgre"
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
    if [ -z "$branch" ]; then
        git clone "https://github.com/${org}/${repo}.git" \
            --depth 1 --quiet "$repodir"
    else
        git clone "https://github.com/${org}/${repo}.git" \
            --single-branch --branch "${branch}" \
            --quiet "${repodir}"
    fi
else
    cd "$repodir"
    echo_job_info "clean module project"
    git reset HEAD --hard
    echo_job_info "git fetch module project"
    git fetch --all
    if [ -z "$branch" ]; then
        if git branch -va | grep origin/main 1>/dev/null 2>&1
        then
            branch=main
        else
            branch=master
        fi
    fi
    echo_job_info "git checkout out $branch of module project"
    git checkout origin/"$branch"
fi

# * PREPARATION
case "$lang" in
    sql-postgre)
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
