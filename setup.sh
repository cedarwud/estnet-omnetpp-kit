#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT
source "${PROJECT_ROOT}/scripts/common.sh"

usage() {
    cat <<'EOF'
Usage: ./setup.sh [ready|baseline|full|ide] [--force] [--skip-apt]

Default:
  ready     Preferred one-time setup path for a new environment.

Modes:
  ready     Build the preferred baseline flow and OMNeT++ IDE payload.
  baseline  Build only the baseline flow, without IDE packaging.
  full      Build baseline + osgEarth Method B + OMNeT++ IDE payload.
  ide       Rebuild only the OMNeT++ IDE payload.

Options:
  --force    Force rerun each stage even if state says success.
  --skip-apt Skip apt prerequisite installation in setup.sh.
EOF
}

MODE="ready"
SKIP_APT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        ready|baseline|full|ide)
            MODE="$1"
            shift
            ;;
        --skip-apt)
            SKIP_APT=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --force)
            break
            ;;
        *)
            printf "Unknown argument: %s\n\n" "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

install_prerequisites() {
    if [[ "${SKIP_APT}" == "1" ]]; then
        printf "[setup] skip apt prerequisite installation (--skip-apt)\n"
        return 0
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        printf "[setup] apt-get not found; skipping prerequisite installation\n"
        return 0
    fi

    local -a packages=(
        build-essential cmake pkg-config
        default-jre default-jdk
        bison flex
        maven swig
        qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools libqt5opengl5-dev
        libwebkit2gtk-4.0-37
        libgl1-mesa-dev libglu1-mesa-dev
        libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libxmu-dev
        libjpeg-dev libpng-dev libtiff-dev libfreetype6-dev zlib1g-dev libfontconfig1-dev
        libcurl4-openssl-dev libgdal-dev libgeos-dev libsqlite3-dev
    )

    printf "[setup] installing Ubuntu prerequisites via apt\n"
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
}

cd "${PROJECT_ROOT}"
printf "[setup] environment=%s distro=%s version=%s codename=%s virt=%s\n" \
    "$(detect_runtime_environment)" \
    "$(linux_distro_id || true)" \
    "$(linux_distro_version_id || true)" \
    "$(linux_distro_codename || true)" \
    "$(detect_virtualization || true)"
install_prerequisites
exec "${PROJECT_ROOT}/tools/run_all.sh" "${MODE}" "$@"
