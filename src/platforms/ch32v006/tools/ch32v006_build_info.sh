#!/bin/sh
# SPDX-FileCopyrightText: AtomVM Contributors
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later

# Emit a host build record, not a hardware qualification result.
set -eu

if [ "$#" -lt 7 ]; then
    echo "Usage: $0 ATOMVM_ROOT CH32FUN CC IMAGE ELF EMBEDDED_BEAM INPUT [KEY=VALUE ...]" >&2
    exit 1
fi

atomvm_root=$1
ch32fun_dir=$2
compiler=$3
image=$4
elf=$5
embedded_beam=$6
input=$7
shift 7

checksum()
{
    digest=$(sha256sum "$2")
    printf '%s_sha256=%s\n' "$1" "${digest%% *}"
}

revision()
{
    label=$1
    directory=$2
    if commit=$(git -C "$directory" rev-parse --verify HEAD 2>/dev/null); then
        printf '%s_commit=%s\n' "$label" "$commit"
        state=$(git -C "$directory" status --porcelain=v1 --untracked-files=normal)
        if [ -n "$state" ]; then
            printf '%s_worktree=dirty\n%s_status_begin\n%s\n%s_status_end\n' \
                "$label" "$label" "$state" "$label"
        else
            printf '%s_worktree=clean\n' "$label"
        fi
    else
        printf '%s_commit=unknown\n%s_worktree=unknown\n' "$label" "$label"
    fi
}

printf 'format=ch32v006-build-info-v1\n'
printf 'hardware_test=not-recorded\n'
printf 'image=%s\ninput=%s\n' "$image" "$input"
checksum image "$image"
checksum elf "$elf"
checksum embedded_beam "$embedded_beam"
checksum input "$input"
printf 'image_bytes=%s\n' "$(wc -c < "$image" | tr -d ' ')"
revision atomvm "$atomvm_root"
revision ch32fun "$ch32fun_dir"
printf 'compiler=%s\n' "$compiler"
compiler_version=$("$compiler" --version)
printf '%s\n' "$compiler_version" | sed -n '1s/^/compiler_version=/p'
erl -noshell -eval 'io:format("otp_release=~s~nerts_version=~s~n", [erlang:system_info(otp_release), erlang:system_info(version)]), halt().'
printf '%s\n' "$@"
