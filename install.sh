#!/usr/bin/env sh
set -e

# curl -LsSf https://raw.githubusercontent.com/mokeyish/nupk/main/install.sh | sh -s -- <install dir>
INSTALL_DIR="$1"
[ -n "$INSTALL_DIR" ] || INSTALL_DIR="$HOME/.nupk"
[ -n "$PREFIX" ] || PREFIX="$HOME/.local"

ver_gte() {
    v1=$1
    v2=$2
    # 把版本号按点切分，补齐到 3 段
    set -- $(echo "$v1" | awk -F. '{printf "%d %d %d", $1,$2,$3}')
    a1=$1; a2=$2; a3=$3
    set -- $(echo "$v2" | awk -F. '{printf "%d %d %d", $1,$2,$3}')
    b1=$1; b2=$2; b3=$3

    if [ "$a1" -gt "$b1" ]; then return 0; fi
    if [ "$a1" -lt "$b1" ]; then return 1; fi

    if [ "$a2" -gt "$b2" ]; then return 0; fi
    if [ "$a2" -lt "$b2" ]; then return 1; fi

    if [ "$a3" -ge "$b3" ]; then return 0; fi

    return 1
}

echo "Cloning nupk to $INSTALL_DIR..."
git clone --depth 1 --no-checkout https://github.com/mokeyish/nupk.git "$INSTALL_DIR"

cd "$INSTALL_DIR"

current_git_version=$(git --version | awk '{print $3}')
required_git_version="2.25.0"

if ver_gte "$current_git_version" "$required_git_version"; then
    git config core.sparseCheckout true
    git sparse-checkout set --no-cone '/*' '!/**/tests/' '!/install.sh'
else
    echo "Warning: Sparse checkout is not supported in your git version."
    echo "Please upgrade git to $required_git_version or later."
fi

git checkout

chmod +x nupk.nu

echo "Installing nupk to $PREFIX/bin..."
mkdir -p "$PREFIX/bin"
ln -sf "$INSTALL_DIR/nupk.nu" "$PREFIX/bin/nupk"

"$PREFIX/bin/nupk" info || true

echo "Installation complete. You can now use 'nupk' command."


# 检查 PATH 里是否有 $PREFIX/bin
case ":$PATH:" in
  *":$PREFIX/bin:"*) ;;
  *)
    echo ""
    echo "⚠️  Warning: $PREFIX/bin is not in your PATH."
    echo "   Please add the following line to your shell rc file (e.g. ~/.bashrc or ~/.zshrc):"
    echo "     export PATH=\"$PREFIX/bin:\$PATH\""
    ;;
esac
