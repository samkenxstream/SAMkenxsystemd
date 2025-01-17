#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later

# Utility functions for shell tests

assert_true() {(
    set +ex

    local rc

    "$@"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "FAIL: command '$*' failed with exit code $rc" >&2
        exit 1
    fi
)}


assert_eq() {(
    set +ex

    if [[ "${1?}" != "${2?}" ]]; then
        echo "FAIL: expected: '$2' actual: '$1'" >&2
        exit 1
    fi
)}

assert_in() {(
    set +ex

    if ! [[ "${2?}" =~ ${1?} ]]; then
        echo "FAIL: '$1' not found in:" >&2
        echo "$2" >&2
        exit 1
    fi
)}

assert_not_in() {(
    set +ex

    if [[ "${2?}" =~ ${1?} ]]; then
        echo "FAIL: '$1' found in:" >&2
        echo "$2" >&2
        exit 1
    fi
)}

assert_rc() {(
    set +ex

    local rc exp="${1?}"

    shift
    "$@"
    rc=$?
    assert_eq "$rc" "$exp"
)}

get_cgroup_hierarchy() {
    case "$(stat -c '%T' -f /sys/fs/cgroup)" in
        cgroup2fs)
            echo "unified"
            ;;
        tmpfs)
            if [[ -d /sys/fs/cgroup/unified && "$(stat -c '%T' -f /sys/fs/cgroup/unified)" == cgroup2fs ]]; then
                echo "hybrid"
            else
                echo "legacy"
            fi
            ;;
        *)
            echo >&2 "Failed to determine host's cgroup hierarchy"
            exit 1
    esac
}

runas() {
    local userid="${1:?}"
    shift
    XDG_RUNTIME_DIR=/run/user/"$(id -u "$userid")" setpriv --reuid="$userid" --init-groups "$@"
}

coverage_create_nspawn_dropin() {
    # If we're collecting coverage, bind mount the $BUILD_DIR into the nspawn
    # container so gcov can update the counters. This is mostly for standalone
    # containers, as machinectl stuff is handled by overriding the systemd-nspawn@.service
    # (see test/test-functions:install_systemd())
    local root="${1:?}"
    local container

    if [[ -z "${COVERAGE_BUILD_DIR:-}" ]]; then
        return 0
    fi

    container="$(basename "$root")"
    mkdir -p "/run/systemd/nspawn"
    echo -ne "[Files]\nBind=$COVERAGE_BUILD_DIR\n" >"/run/systemd/nspawn/${container:?}.nspawn"
}

create_dummy_container() {
    local root="${1:?}"

    if [[ ! -d /testsuite-13-container-template ]]; then
        echo >&2 "Missing container template, probably not running in TEST-13-NSPAWN?"
        exit 1
    fi

    mkdir -p "$root"
    cp -a /testsuite-13-container-template/* "$root"
    coverage_create_nspawn_dropin "$root"
}
