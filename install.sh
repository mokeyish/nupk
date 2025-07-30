#!/bin/env bash

set -e

# curl -LsSf https://raw.githubusercontent.com/mokeyish/nupk/main/install.sh | sh -s -- <install dir>
INSATLL_DIR="$1"

INSATLL_DIR=${INSATLL_DIR:=$HOME/.nupk}

echo "Cloning nupk to $INSATLL_DIR..."

git clone --depth 1 --no-checkout https://github.com/mokeyish/nupk.git $INSATLL_DIR

cd $INSATLL_DIR

git config core.sparseCheckout true

git sparse-checkout set --no-cone  '/*' '!/**/tests/' '!/install.sh' '!/test.nu'


git checkout

chmod +x nupk.nu

echo "Installing nupk to $HOME/.local/bin..."
ln -sf $INSATLL_DIR/nupk.nu $HOME/.local/bin/nupk


nupk info

echo "Installation complete. You can now use 'nupk' command."