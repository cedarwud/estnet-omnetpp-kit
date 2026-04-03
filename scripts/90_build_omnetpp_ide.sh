#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

init_stage "90" "build_omnetpp_ide"
trap 'handle_unexpected_error $? ${LINENO} "${BASH_COMMAND}"' ERR

if stage_should_skip; then
    exit 0
fi

stage_begin_work

need_command() {
    local cmd="$1"
    local pkg="$2"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        stage_mark_failure "Required command '${cmd}' is missing. Install package '${pkg}' and rerun Stage 90."
    fi
}

need_stage_success() {
    local stage_id="$1"
    local description="$2"
    local state_file="${STATE_DIR}/${stage_id}.state"
    if [[ ! -f "${state_file}" ]]; then
        stage_mark_failure "${description} has not been run yet. Missing state file: ${state_file}"
    fi
    if ! grep -Fxq "status=success" "${state_file}"; then
        local status
        status="$(sed -n 's/^status=//p' "${state_file}" | head -n1)"
        stage_mark_failure "${description} is not in success state (current: ${status:-unknown}). Resolve that stage first."
    fi
}

need_stage_success "40" "Stage 40 (OMNeT++ build)"
need_stage_success "70" "Stage 70 (activation script)"

need_command "mvn" "maven"
need_command "swig" "swig"
need_command "perl" "perl"
need_command "python3" "python3"
need_command "cp" "coreutils"
need_command "ln" "coreutils"
need_command "make" "make"
need_command "find" "findutils"

if [[ ! -d "${OMNETPP_DIR}/.git" ]]; then
    stage_mark_failure "OMNeT++ source tree is missing at ${OMNETPP_DIR}. Run Stage 10 first."
fi
if [[ "$(git -C "${OMNETPP_DIR}" rev-parse HEAD)" != "${OMNETPP_COMMIT}" ]]; then
    stage_mark_failure "OMNeT++ source tree at ${OMNETPP_DIR} is not pinned to ${OMNETPP_COMMIT}. Re-run Stage 10."
fi

export PATH="${OMNETPP_DIR}/bin:${PATH}"

IDE_STAGE_DIR="${OMNETPP_IDE_BUILD_BASE}/${RUN_TS}"
IDE_WORK_UI_DIR="${IDE_STAGE_DIR}/ui"
IDE_PRODUCT_DIR="${IDE_WORK_UI_DIR}/releng/org.omnetpp.ide.product/target/products/org.omnetpp.ide.product/linux/gtk/x86_64"
IDE_LINK_PATH="${OMNETPP_DIR}/ide"

append_summary "ide_stage_dir=${IDE_STAGE_DIR}"
append_summary "ide_work_ui_dir=${IDE_WORK_UI_DIR}"
append_summary "ide_product_dir=${IDE_PRODUCT_DIR}"
append_summary "ide_link_path=${IDE_LINK_PATH}"
append_summary "ide_repo.main=${OMNETPP_IDE_MAIN_REPO_URL}"
append_summary "ide_repo.update=${OMNETPP_IDE_UPDATE_REPO_URL}"
append_summary "ide_repo.cdt=${OMNETPP_IDE_CDT_REPO_URL}"

set_checkpoint "ui_libs" "building OMNeT++ IDE native libraries"
(
    cd "${OMNETPP_DIR}"
    make MODE=release SWIG=swig JNILIBS_IF_POSSIBLE=jnilibs ui
)

if [[ ! -f "${OMNETPP_DIR}/ui/org.omnetpp.ide.nativelibs.linux.x86_64/libopplibs.so" ]]; then
    stage_mark_failure "UI native library build completed but libopplibs.so was not produced."
fi

append_summary "artifact.native_linux_lib=${OMNETPP_DIR}/ui/org.omnetpp.ide.nativelibs.linux.x86_64/libopplibs.so"

set_checkpoint "workspace_copy" "creating isolated UI packaging workspace"
mkdir -p "${IDE_STAGE_DIR}"
cp -a "${OMNETPP_DIR}/ui" "${IDE_WORK_UI_DIR}"
touch "${IDE_WORK_UI_DIR}/org.omnetpp.ide.nativelibs.win32.x86_64/opplibs.dll"
touch "${IDE_WORK_UI_DIR}/org.omnetpp.ide.nativelibs.macosx/libopplibs.jnilib"

set_checkpoint "workspace_sanitize" "removing unavailable OMNEST/commercial modules from isolated reactor"
python3 - "${IDE_WORK_UI_DIR}" <<'PY'
import pathlib
import sys

ui_dir = pathlib.Path(sys.argv[1])

def remove_module(pom_path: pathlib.Path, module_name: str) -> bool:
    original = pom_path.read_text(encoding="utf-8")
    needle = f"    <module>{module_name}</module>\n"
    if needle not in original:
        return False
    pom_path.write_text(original.replace(needle, ""), encoding="utf-8")
    return True

removed = []
if remove_module(ui_dir / "pom.xml", "org.omnetpp.main.omnest"):
    removed.append("ui/pom.xml:org.omnetpp.main.omnest")
if remove_module(ui_dir / "features" / "pom.xml", "org.omnetpp.ide.commercial"):
    removed.append("ui/features/pom.xml:org.omnetpp.ide.commercial")

if removed:
    print("removed=" + ",".join(removed))
else:
    print("removed=none")

patched = []

def patch_compat_methods(relative_path: str, marker: str, compat_methods: str, guard: str) -> None:
    path = ui_dir / relative_path
    if not path.exists():
        patched.append(f"missing:{relative_path}")
        return

    original = path.read_text(encoding="utf-8")
    if guard in original:
        patched.append(f"already:{relative_path}")
        return
    if marker not in original:
        patched.append(f"marker-missing:{relative_path}")
        return

    path.write_text(original.replace(marker, compat_methods + marker, 1), encoding="utf-8")
    patched.append(f"{relative_path}:compat")

patch_compat_methods(
    "org.omnetpp.ide.nativelibs/src/org/omnetpp/scave/engine/StringMap.java",
    "  public String remove(java.lang.Object key) {\n",
    (
        "  // SWIG 4 generates java.util.Map-style put(); older OMNeT++ UI code still calls set().\n"
        "  public void set(String key, String value) {\n"
        "    put(key, value);\n"
        "  }\n\n"
        "  public boolean has_key(String key) {\n"
        "    return containsKey(key);\n"
        "  }\n\n"
        "  public void del(String key) {\n"
        "    remove(key);\n"
        "  }\n\n"
    ),
    "public void set(String key, String value)",
)

patch_compat_methods(
    "org.omnetpp.ide.nativelibs/src/org/omnetpp/eventlog/engine/IntIntMap.java",
    "  public Integer remove(java.lang.Object key) {\n",
    (
        "  // SWIG 4 generates java.util.Map-style put(); older OMNeT++ UI code still calls set().\n"
        "  public void set(int key, int value) {\n"
        "    put(key, value);\n"
        "  }\n\n"
        "  public void set(Integer key, Integer value) {\n"
        "    put(key, value);\n"
        "  }\n\n"
        "  public boolean has_key(int key) {\n"
        "    return containsKey(key);\n"
        "  }\n\n"
        "  public boolean has_key(Integer key) {\n"
        "    return containsKey(key);\n"
        "  }\n\n"
        "  public void del(int key) {\n"
        "    remove(key);\n"
        "  }\n\n"
        "  public void del(Integer key) {\n"
        "    remove(key);\n"
        "  }\n\n"
    ),
    "public void set(int key, int value)",
)

startup_java = ui_dir / "org.omnetpp.main" / "src" / "org" / "omnetpp" / "ide" / "OmnetppStartup.java"
startup_original = startup_java.read_text(encoding="utf-8")
startup_marker = "                                openInitialPages(dialog.isImportSamplesRequested());\n"
startup_replacement = (
    "                                // On WSL and minimal Linux installs, SWT's internal Browser widget may be unavailable.\n"
    "                                // Skip auto-opening browser-backed welcome/documentation pages during first startup.\n"
    "                                // Users can still open documentation later after installing WebKitGTK.\n"
    "                                // openInitialPages(dialog.isImportSamplesRequested());\n"
)
if startup_marker in startup_original and startup_replacement not in startup_original:
    startup_java.write_text(startup_original.replace(startup_marker, startup_replacement, 1), encoding="utf-8")
    patched.append("org.omnetpp.main/src/org/omnetpp/ide/OmnetppStartup.java:skip_initial_browser_pages")
elif startup_replacement in startup_original:
    patched.append("already:org.omnetpp.main/src/org/omnetpp/ide/OmnetppStartup.java")
else:
    patched.append("marker-missing:org.omnetpp.main/src/org/omnetpp/ide/OmnetppStartup.java")

print("patched=" + ",".join(patched))
PY

set_checkpoint "tycho_build" "building OMNeT++ IDE product with Maven/Tycho"
(
    cd "${IDE_WORK_UI_DIR}"
    mvn clean verify \
        -Dwhat=omnetpp \
        -DforceContextQualifier="${RUN_TS}" \
        -Drepo.url="${OMNETPP_IDE_MAIN_REPO_URL}" \
        -Dupdate-repo.url="${OMNETPP_IDE_UPDATE_REPO_URL}" \
        -Dcdt-repo.url="${OMNETPP_IDE_CDT_REPO_URL}"
)

if [[ ! -d "${IDE_PRODUCT_DIR}" ]]; then
    stage_mark_failure "Tycho build completed but expected Linux IDE product directory is missing: ${IDE_PRODUCT_DIR}"
fi
if [[ ! -f "${IDE_PRODUCT_DIR}/omnetpp" ]]; then
    stage_mark_failure "Tycho build completed but Linux IDE launcher was not found at ${IDE_PRODUCT_DIR}/omnetpp"
fi
if [[ ! -d "${IDE_PRODUCT_DIR}/configuration" ]]; then
    stage_mark_failure "Tycho build completed but configuration directory is missing at ${IDE_PRODUCT_DIR}/configuration"
fi

append_summary "artifact.ide_launcher=${IDE_PRODUCT_DIR}/omnetpp"
append_summary "artifact.ide_configuration=${IDE_PRODUCT_DIR}/configuration"

set_checkpoint "install_link" "linking built IDE payload into OMNeT++ tree"
if [[ -e "${IDE_LINK_PATH}" ]] && [[ ! -L "${IDE_LINK_PATH}" ]]; then
    stage_mark_failure "Refusing to replace existing non-symlink IDE path: ${IDE_LINK_PATH}"
fi
IDE_LINK_TARGET_REL="$(python3 - "${OMNETPP_DIR}" "${IDE_PRODUCT_DIR}" <<'PY'
import os
import sys

omnetpp_dir = sys.argv[1]
ide_product_dir = sys.argv[2]
print(os.path.relpath(ide_product_dir, omnetpp_dir))
PY
)"
append_summary "ide_link_target_rel=${IDE_LINK_TARGET_REL}"
ln -sfn "${IDE_LINK_TARGET_REL}" "${IDE_LINK_PATH}"

if [[ ! -x "${IDE_LINK_PATH}/omnetpp" ]]; then
    stage_mark_failure "Linked IDE payload exists but launcher is not executable: ${IDE_LINK_PATH}/omnetpp"
fi

stage_mark_success "OMNeT++ IDE payload built and linked at ${IDE_LINK_PATH}."
