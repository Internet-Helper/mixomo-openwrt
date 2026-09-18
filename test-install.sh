#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
MIXOMO_VERSION=v0.3.0-prerelease
MIXOMO_DEFAULT_MANIFEST=https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/manifest.test
MIXOMO_SOURCE_URL=https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt
MIXOMO_MANIFEST_PATH=${MIXOMO_MANIFEST_PATH:-$MIXOMO_DEFAULT_MANIFEST}
MIXOMO_SOURCE_ROOT=${MIXOMO_SOURCE_ROOT:-$SCRIPT_DIR}
MIXOMO_LOCAL_ROOT=${MIXOMO_LOCAL_ROOT:-}
MIXOMO_LAUNCH_DIR=$(pwd)
MIXOMO_REF_OVERRIDE=${MIXOMO_REF:-}
MIXOMO_KEEP_STAGE=${MIXOMO_KEEP_STAGE:-0}
STAGE=
MANIFEST=
BUNDLE_FILE=

fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time 300 -o "$1" "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 300 -O "$1" "$2"
    else
        fail "Нет curl или wget для загрузки"
    fi
}
local_roots() {
    printf '%s\n' "$MIXOMO_LOCAL_ROOT" "$SCRIPT_DIR" "$SCRIPT_DIR/mixomo" "$MIXOMO_LAUNCH_DIR/mixomo" "$MIXOMO_LAUNCH_DIR"
}

acquire_bundle() {
    local root
    while IFS= read -r root; do
        [ -n "$root" ] || continue
        if [ -f "$root/$bundle" ]; then
            cp -f "$root/$bundle" "$BUNDLE_FILE"
            return 0
        fi
    done <<EOF
$(local_roots)
EOF
    if [ "$ref" = local ] || [ "${MIXOMO_LOCAL_ONLY:-0}" = 1 ]; then
        fail "Локальный bundle не найден: $bundle"
    fi
    download "$BUNDLE_FILE" "$source_base/$bundle"
}
manifest_value() { awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$MANIFEST"; }
validate_ref() { case "$1" in local|main|v[0-9A-Za-z._-]*|[0-9a-fA-F][0-9a-fA-F]*) ;; *) fail "Некорректный ref: $1" ;; esac; }
validate_bundle() { case "$1" in ''|../*|*/../*|/*) fail "Некорректный путь к bundle" ;; esac; }
verify_hash() {
    expected=$1
    file=$2
    case "$expected" in '') return 0 ;; esac
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null 2>&1
    elif command -v busybox >/dev/null 2>&1 && busybox sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$expected" "$file" | busybox sha256sum -c - >/dev/null 2>&1
    else
        fail "Нет команды для проверки SHA-256"
    fi
}
cleanup() {
    if [ "$MIXOMO_KEEP_STAGE" = 1 ]; then
        printf 'Stage: %s\n' "$STAGE"
    else
        [ -n "$STAGE" ] && rm -rf "$STAGE" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

if [ -f "$MIXOMO_MANIFEST_PATH" ]; then
    MANIFEST=$MIXOMO_MANIFEST_PATH
elif case "$MIXOMO_MANIFEST_PATH" in file://*) true;; *) false;; esac; then
    MANIFEST=${MIXOMO_MANIFEST_PATH#file://}
elif [ "${MIXOMO_LOCAL_ONLY:-0}" != 1 ]; then
    manifest_name=${MIXOMO_MANIFEST_PATH##*/}
    while IFS= read -r root; do
        [ -n "$root" ] || continue
        if [ -f "$root/$manifest_name" ]; then
            MANIFEST=$root/$manifest_name
            break
        fi
    done <<EOF
$(local_roots)
EOF
    if [ -z "$MANIFEST" ]; then
        MANIFEST=$(mktemp /tmp/mixomo-manifest.XXXXXX)
        download "$MANIFEST" "$MIXOMO_MANIFEST_PATH" || fail "Не удалось скачать manifest"
    fi
else
    manifest_name=${MIXOMO_MANIFEST_PATH##*/}
    while IFS= read -r root; do
        [ -n "$root" ] || continue
        if [ -f "$root/$manifest_name" ]; then
            MANIFEST=$root/$manifest_name
            break
        fi
    done <<EOF
$(local_roots)
EOF
    [ -n "$MANIFEST" ] || fail "Локальный manifest не найден: $manifest_name"
fi
[ -s "$MANIFEST" ] || fail "Manifest пустой"
schema=$(manifest_value MIXOMO_SCHEMA)
version=$(manifest_value MIXOMO_VERSION)
ref=${MIXOMO_REF_OVERRIDE:-$(manifest_value MIXOMO_REF)}
bundle=$(manifest_value MIXOMO_BUNDLE)
expected=$(manifest_value MIXOMO_BUNDLE_SHA256)
[ "$schema" = 1 ] || fail "Неподдерживаемая версия manifest"
[ "$version" = "$MIXOMO_VERSION" ] || fail "Несовместимая версия: $version"
validate_ref "$ref"
validate_bundle "$bundle"
STAGE=$(mktemp -d /tmp/mixomo-stage.XXXXXX) || fail "Не удалось создать временный каталог"
BUNDLE_FILE=$STAGE/bundle.tar.gz
if [ "$ref" = local ]; then
    source_base=$MIXOMO_SOURCE_ROOT
else
    source_base=$MIXOMO_SOURCE_URL/$ref
fi
acquire_bundle || fail "Не удалось получить release bundle"
verify_hash "$expected" "$BUNDLE_FILE" || fail "Не совпал SHA-256 release bundle"
tar -xzf "$BUNDLE_FILE" -C "$STAGE" || fail "Не удалось распаковать release bundle"
[ -f "$STAGE/src/main.sh" ] || fail "В bundle отсутствует src/main.sh"
export MIXOMO_INSTALLED_VERSION=$version MIXOMO_BUNDLE_SHA=$expected
MIXOMO_SOURCE_ROOT=$STAGE MIXOMO_ASSET_ROOT=$STAGE/src/assets sh "$STAGE/src/main.sh" "$@"
