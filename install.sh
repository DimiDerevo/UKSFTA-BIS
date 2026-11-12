#!/usr/bin/env bash
# Installs the "bis" command for the current Linux or macOS user.
#
# The script finds the bis binary in one of two ways:
#   1. A "bis" file next to this script (release archive): the script uses that file.
#   2. A source checkout: the script builds a self-contained binary.
#      This needs the .NET 10 SDK. The installed binary does not need .NET.
#
# Usage:
#   ./install.sh                  install to ~/.local/bin
#   ./install.sh --dir /some/dir  install to another folder
#   ./install.sh --uninstall      remove bis
#
# Run the script again to update bis.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
UNINSTALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir) INSTALL_DIR="$2"; shift 2 ;;
        --uninstall) UNINSTALL=1; shift ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

TARGET="${INSTALL_DIR}/bis"

if [[ $UNINSTALL -eq 1 ]]; then
    rm -f "$TARGET"
    echo "Removed $TARGET"
    exit 0
fi

# 1. Find or build the binary.
if [[ -f "${ROOT}/bis" ]]; then
    SOURCE="${ROOT}/bis"
    echo "Using $SOURCE"
elif [[ -f "${ROOT}/BIS.CLI/BIS.CLI.csproj" ]]; then
    if ! command -v dotnet >/dev/null 2>&1; then
        echo "The .NET 10 SDK is necessary to build from source. Get it from https://dotnet.microsoft.com/download" >&2
        exit 1
    fi

    case "$(uname -s)" in
        Linux) os="linux" ;;
        Darwin) os="osx" ;;
        *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64) arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
    esac
    RID="${os}-${arch}"
    PUBLISH_DIR="${ROOT}/artifacts/publish/${RID}"
    echo "Building bis for ${RID} ..."

    dotnet publish "${ROOT}/BIS.CLI/BIS.CLI.csproj" -c Release -r "$RID" --self-contained true \
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
        -p:DebugType=none -o "$PUBLISH_DIR"

    SOURCE="${PUBLISH_DIR}/BIS.CLI"
else
    echo "Cannot find bis or BIS.CLI/BIS.CLI.csproj next to this script (${ROOT})." >&2
    exit 1
fi

# 2. Copy the binary to the install folder.
mkdir -p "$INSTALL_DIR"
install -m 755 "$SOURCE" "$TARGET"
echo "Installed $TARGET"

# 3. Check the PATH. The script does not edit shell profiles.
case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        echo
        echo "${INSTALL_DIR} is not in PATH. Add this line to ~/.bashrc or ~/.profile:"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
        ;;
esac

echo
echo "Done. Run: bis --help"
