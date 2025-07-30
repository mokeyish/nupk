#!/bin/env sh

set -e

# curl -LsSf https://raw.githubusercontent.com/mokeyish/nupk/main/install.sh | sh -s -- <install dir>
INSATLL_DIR="$1"

INSATLL_DIR=${INSATLL_DIR:=$HOME/.nupk}

ver_gte()
{
    printf '%s\n%s\n' "$2" "$1" | sort --check=quiet --version-sort
}

echo "Cloning nupk to $INSATLL_DIR..."

git clone --depth 1 --no-checkout https://github.com/mokeyish/nupk.git $INSATLL_DIR

cd $INSATLL_DIR

if ver_gte $(git --version) 2.25.0;then
    git config core.sparseCheckout true

    git sparse-checkout set --no-cone  '/*' '!/**/tests/' '!/install.sh'
else
    echo "Warning: Sparse checkout is not supported in your git version, please upgrade git to 2.25.0 or later."
fi


git checkout

chmod +x nupk.nu

echo "Installing nupk to $HOME/.local/bin..."
ln -sf $INSATLL_DIR/nupk.nu $HOME/.local/bin/nupk


nupk info

echo "Installation complete. You can now use 'nupk' command."
