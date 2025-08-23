#!/bin/env sh

set -e

# curl -LsSf https://raw.githubusercontent.com/mokeyish/nupk/main/install.sh | sh -s -- <install dir>
INSATLL_DIR="$1"

INSATLL_DIR=${INSATLL_DIR:=$HOME/.nupk}
PREFIX=${PREFIX:=$HOME/.local}

ver_gte() {
    ver_arr() {
        IFS='.' read -r -a ver <<< "$1"
        echo "${ver[@]}"
    }

    local curr=($(ver_arr "$1"))
    local req=($(ver_arr "$2"))

    for i in 0 1 2; do
        curr_val=${curr[i]:-0}
        req_val=${req[i]:-0}

        if (( curr_val > req_val )); then
            return 0
        elif (( curr_val < req_val )); then
            return 1
        fi
    done

    # 版本号相等
    return 1
}

echo "Cloning nupk to $INSATLL_DIR..."

git clone --depth 1 --no-checkout https://github.com/mokeyish/nupk.git $INSATLL_DIR

cd $INSATLL_DIR

currrent_git_version=$(git --version | awk '{print $3}')
required_git_version="2.25.0"
if ver_gte "$currrent_git_version" "$required_git_version";then
    git config core.sparseCheckout true
    git sparse-checkout set --no-cone  '/*' '!/**/tests/' '!/install.sh'
else
    echo "Warning: Sparse checkout is not supported in your git version, please upgrade git to $required_git_version or later."
fi


git checkout

chmod +x nupk.nu

echo "Installing nupk to $PREFIX/bin..."
mkdir -p $PREFIX/bin
ln -sf $INSATLL_DIR/nupk.nu $PREFIX/bin/nupk


nupk info

echo "Installation complete. You can now use 'nupk' command."
