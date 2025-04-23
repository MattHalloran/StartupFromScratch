#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "${HERE}/../utils/index.sh"

# Function to install ShellCheck for shell script linting
install_shellcheck() {
    # Check if ShellCheck is already installed
    if command -v shellcheck >/dev/null 2>&1; then
        info "ShellCheck is already installed"
        return
    fi

    header "🔍 Installing ShellCheck for shell linting"

    # First attempt: install via system package manager
    if install_system_package shellcheck; then
        success "ShellCheck installed via package manager"
        return
    else
        warning "Package manager install failed or timed out, falling back to GitHub releases"
    fi

    # Determine architecture for static binary
    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac

    # List of ShellCheck versions to try (newest first)
    fallback_versions=("0.10.0" "0.9.0" "0.8.0")
    for version in "${fallback_versions[@]}"; do
        header "📥 Attempting to download ShellCheck v${version} for ${arch}"
        tmpdir=$(mktemp -d)
        if curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v${version}/shellcheck-v${version}.linux.${arch}.tar.xz" \
               | tar -xJ -C "$tmpdir"; then
            sudo mv "$tmpdir/shellcheck-v${version}/shellcheck" /usr/local/bin/shellcheck
            sudo chmod +x /usr/local/bin/shellcheck
            rm -rf "$tmpdir"
            success "ShellCheck v${version} installed from GitHub releases"
            return
        else
            warning "Download of ShellCheck v${version} failed, trying next version"
            rm -rf "$tmpdir"
        fi
    done

    error "All fallback ShellCheck installations failed"
}
