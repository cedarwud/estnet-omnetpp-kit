#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT
source "${PROJECT_ROOT}/scripts/common.sh"
GL_MODE="${OMNETPP_GL_MODE:-auto}"
ENV_KIND="$(detect_runtime_environment)"

case "${1:-}" in
    --software-gl)
        GL_MODE="software"
        shift
        ;;
    --native-gl)
        GL_MODE="native"
        shift
        ;;
esac

if [[ ! -f "${PROJECT_ROOT}/activate_env.sh" ]]; then
    printf "Missing %s/activate_env.sh. Run ./setup.sh first in this project root.\n" "${PROJECT_ROOT}" >&2
    exit 1
fi

source "${PROJECT_ROOT}/activate_env.sh"

if [[ "${GL_MODE}" == "auto" ]]; then
    GL_MODE="$(default_gl_mode_for_environment)"
fi

printf "[run] environment=%s distro=%s version=%s codename=%s virt=%s gl_mode=%s\n" \
    "${ENV_KIND}" \
    "$(linux_distro_id || true)" \
    "$(linux_distro_version_id || true)" \
    "$(linux_distro_codename || true)" \
    "$(detect_virtualization || true)" \
    "${GL_MODE}"

if [[ "${GL_MODE}" == "software" ]]; then
    # WSLg's D3D12-backed OpenGL translation is unstable with Qtenv+OSG/osgEarth.
    # Default to Mesa software rendering on WSL; keep native GL elsewhere.
    export LIBGL_ALWAYS_SOFTWARE=1
    export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
    export GALLIUM_DRIVER=llvmpipe
else
    unset LIBGL_ALWAYS_SOFTWARE
    unset MESA_LOADER_DRIVER_OVERRIDE
    unset GALLIUM_DRIVER
fi

exec omnetpp "$@"
