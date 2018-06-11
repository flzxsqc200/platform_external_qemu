# This script is sourced from the top-level Android emulator
# configuration script, and relies on the following macro
# definitions:
#
#  QEMU2_TOP_DIR: top-level QEMU2 source directory.
#  QEMU2_TRACE: the tracers that should be enabled
#  OUT_DIR: top-level build output directory.

if  [ -z "$QEMU2_TOP_DIR" ] ||
    [ -z "$QEMU2_TRACE" ] ||
    [ -z "$OUT_DIR" ] ;
then
  echo "This script needs to be sourced from configure.sh, with the proper variables set."
  exit 1
fi


QEMU2_AUTOGENERATED_DIR=$OUT_DIR/build/qemu2-qapi-auto-generated

replace_with_if_different () {
    cmp -s "$1" "$2" || mv "$2" "$1"
}

probe_prebuilts_dir "QEMU2 Dependencies" \
    QEMU2_DEPS_PREBUILTS_DIR \
    qemu-android-deps

echo "QEMU2_DEPS_PREBUILTS_DIR := $QEMU2_DEPS_PREBUILTS_DIR" >> $config_mk

python $QEMU2_TOP_DIR/scripts/qapi-types.py \
    --builtins \
    -o $QEMU2_AUTOGENERATED_DIR \
    $QEMU2_TOP_DIR/qapi-schema.json || panic "Failed to generate types from qapi-schema.json"

python $QEMU2_TOP_DIR/scripts/qapi-visit.py \
    --builtins \
    -o $QEMU2_AUTOGENERATED_DIR \
    $QEMU2_TOP_DIR/qapi-schema.json || panic "Failed to generate visitors from qapi-schema.json"

python $QEMU2_TOP_DIR/scripts/qapi-event.py \
    -o $QEMU2_AUTOGENERATED_DIR \
    $QEMU2_TOP_DIR/qapi-schema.json || panic "Failed to generate events from qapi-schema.json"

python $QEMU2_TOP_DIR/scripts/qapi-introspect.py \
    -o $QEMU2_AUTOGENERATED_DIR \
    $QEMU2_TOP_DIR/qapi-schema.json || panic "Failed to generate introspect from qapi-schema.json"


python $QEMU2_TOP_DIR/scripts/qapi-commands.py \
    -o $QEMU2_AUTOGENERATED_DIR \
    $QEMU2_TOP_DIR/qapi-schema.json || panic "Failed to generate commands from qapi-schema.json"


python $QEMU2_TOP_DIR/scripts/modules/module_block.py \
     $QEMU2_TOP_DIR/module_block.h || panic "Failed to generate module.h"


generate_trace() {
  local OUT=$1
  local GROUP=$2
  local FORMAT=$3
  local TRACEFILE=$4
  log "GEN $OUT"
  mkdir -p $(dirname $QEMU2_AUTOGENERATED_DIR/$OUT)
  python $QEMU2_TOP_DIR/scripts/tracetool.py \
    --group=$GROUP --format=$FORMAT --backends=$QEMU2_TRACE $TRACEFILE > $QEMU2_AUTOGENERATED_DIR/$OUT || panic "Failed to generate trace $OUT from $TRACEFILE"
}

append_trace() {
  local OUT=trace.h
  local GROUP=$2
  local FORMAT=$3
  local TRACEFILE=$4
  log "GEN $OUT"
  mkdir -p $(dirname $QEMU2_AUTOGENERATED_DIR/$OUT)
  python $QEMU2_TOP_DIR/scripts/tracetool.py \
    --group=$GROUP --format=$FORMAT --backends=$QEMU2_TRACE $TRACEFILE >> $QEMU2_AUTOGENERATED_DIR/$OUT
}

LINES=$(find . -type f -iname 'trace-events')
for LINE in $LINES; do
    TRACE=$(echo ${LINE} | sed 's/\.\///')
    DIR=$(dirname $TRACE)
    NAME=$(echo ${DIR} | sed 's/\//_/g' | sed 's/-/_/g')
    if [ "${NAME}" = "." ]; then
        # Special case root
        generate_trace trace-root.c root c trace-events
        generate_trace trace-root.h root h trace-events
        generate_trace trace/generated-helpers-wrappers.h root tcg-helper-wrapper-h trace-events
        generate_trace trace/generated-helpers.c root tcg-helper-c trace-events
        generate_trace trace/generated-helpers.h root tcg-helper-h trace-events
        generate_trace trace/generated-tcg-tracers.h root tcg-h trace-events
    else
        generate_trace $DIR/trace.h $NAME h $TRACE
        generate_trace $DIR/trace.c $NAME c $TRACE
    fi
done


bash $QEMU2_TOP_DIR/scripts/hxtool -h \
    < $QEMU2_TOP_DIR/qemu-options.hx \
    > $QEMU2_AUTOGENERATED_DIR/qemu-options.def

replace_with_if_different \
    "$QEMU2_TOP_DIR/qemu-options.def" \
    $QEMU2_AUTOGENERATED_DIR/qemu-options.def


bash $QEMU2_TOP_DIR/scripts/hxtool -h \
    < $QEMU2_TOP_DIR/hmp-commands.hx \
    > $QEMU2_AUTOGENERATED_DIR/hmp-commands.h

bash $QEMU2_TOP_DIR/scripts/hxtool -h \
    < $QEMU2_TOP_DIR/hmp-commands-info.hx \
    > $QEMU2_AUTOGENERATED_DIR/hmp-commands-info.h

bash $QEMU2_TOP_DIR/scripts/hxtool -h \
    < $QEMU2_TOP_DIR/qemu-img-cmds.hx \
    > $QEMU2_AUTOGENERATED_DIR/qemu-img-cmds.h

rm -f $QEMU2_AUTOGENERATED_DIR/gdbstub-xml-arm64.c
bash $QEMU2_TOP_DIR/scripts/feature_to_c.sh \
    $QEMU2_AUTOGENERATED_DIR/gdbstub-xml-arm64.c \
    $QEMU2_TOP_DIR/gdb-xml/aarch64-core.xml \
    $QEMU2_TOP_DIR/gdb-xml/aarch64-fpu.xml \
    $QEMU2_TOP_DIR/gdb-xml/arm-core.xml \
    $QEMU2_TOP_DIR/gdb-xml/arm-vfp.xml \
    $QEMU2_TOP_DIR/gdb-xml/arm-vfp3.xml \
    $QEMU2_TOP_DIR/gdb-xml/arm-neon.xml

rm -f $QEMU2_AUTOGENERATED_DIR/gdbstub-xml-arm.c
bash $QEMU2_TOP_DIR/scripts/feature_to_c.sh \
    $QEMU2_AUTOGENERATED_DIR/gdbstub-xml-arm.c \
    $QEMU2_TOP_DIR/gdb-xml/arm-core.xml \
    $QEMU2_TOP_DIR/gdb-xml/arm-vfp.xml \
    $QEMU2_TOP_DIR/gdb-xml/arm-vfp3.xml \
    $QEMU2_TOP_DIR/gdb-xml/arm-neon.xml

if [ "$OPT_MINGW" ]; then
    $OUT_DIR/objs/build/toolchain/x86_64-mingw32-windres \
        -o $QEMU2_AUTOGENERATED_DIR/version.o \
        $QEMU2_TOP_DIR/version.rc
fi

# Generate qemu-version.h from Git history.
QEMU_VERSION_H=$QEMU2_AUTOGENERATED_DIR/qemu-version.h
QEMU_VERSION_H_TMP=$QEMU_VERSION_H.tmp
rm -f "$QEMU_VERSION_H"
if [ -d "$QEMU2_TOP_DIR/.git" ]; then
    QEMU_VERSION=$(cd "$QEMU2_TOP_DIR" && git describe --match 'v*' 2>/dev/null | tr -d '\n')
else
    QEMU_VERSION=$(date "+%Y-%m-%d")
fi

echo "QEMU2    : Version [$QEMU_VERSION]"

printf "#define QEMU_PKGVERSION \"(android-%s)\"\n" "$QEMU_VERSION" > $QEMU_VERSION_H_TMP
replace_with_if_different "$QEMU_VERSION_H" "$QEMU_VERSION_H_TMP"
rm -f "$QEMU_VERSION_TMP_H"

# Work-around for a QEMU2 bug:
# $QEMU2/linux-headers/linux/kvm.h includes <asm/kvm.h>
# but $QEMU2/linux-headers/asm/ doesn't exist. It is supposed
# to be a symlink to $QEMU2/linux-headers/asm-x86/
#
# The end result is that the <asm/kvm.h> from the host system
# or toolchain sysroot is being included, which ends up in a
# conflict. Work around it by creating a symlink here
rm -f $QEMU2_AUTOGENERATED_DIR/asm
ln -sf $QEMU2_TOP_DIR/linux-headers/asm-x86 $QEMU2_AUTOGENERATED_DIR/asm
