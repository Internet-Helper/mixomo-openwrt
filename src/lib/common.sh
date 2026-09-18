for library in paths logging input packages atomic download arch; do
    . "$MIXOMO_LIB_DIR/${library}.sh"
done

MIXOMO_STAGE="${MIXOMO_STAGE:-}"
MIXOMO_SOURCE_ROOT="${MIXOMO_SOURCE_ROOT:-}"
MIXOMO_ASSET_ROOT="${MIXOMO_ASSET_ROOT:-$MIXOMO_SOURCE_ROOT/src/assets}"

asset_path() {
    printf '%s/%s' "$MIXOMO_ASSET_ROOT" "$1"
}
