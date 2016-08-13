# Rules to build the final target-specific QEMU2 binaries from sources.

# The QEMU-specific target name for a given emulator CPU architecture.
QEMU2_TARGET_CPU_x86 := i386
QEMU2_TARGET_CPU_x86_64 := x86_64
QEMU2_TARGET_CPU_mips := mipsel
QEMU2_TARGET_CPU_mips64 := mips64el
QEMU2_TARGET_CPU_arm := arm
QEMU2_TARGET_CPU_arm64 := aarch64

# The engine will use the sources from target-<name> to emulate a given
# emulator CPU architecture.
QEMU2_TARGET_TARGET_x86 := i386
QEMU2_TARGET_TARGET_x86_64 := i386
QEMU2_TARGET_TARGET_mips := mips
QEMU2_TARGET_TARGET_mips64 := mips
QEMU2_TARGET_TARGET_arm := arm
QEMU2_TARGET_TARGET_arm64 := arm

# As a special case, the 32-bit ARM binary is named qemu-system-armel to match
QEMU2_TARGET_CPU := $(QEMU2_TARGET_CPU_$(QEMU2_TARGET))
QEMU2_TARGET_TARGET := $(QEMU2_TARGET_TARGET_$(QEMU2_TARGET))

# upstream QEMU, even though the upstream configure script now uses the 'arm'
# target name (and stores the build files under arm-softmmu instead of
# armel-softmmu. qemu-system-armel is also  what the top-level 'emulator'
# launcher expects.
QEMU2_TARGET_SYSTEM := $(QEMU2_TARGET_CPU)
ifeq (arm,$(QEMU2_TARGET))
    QEMU2_TARGET_SYSTEM := armel
endif

# If $(QEMU2_TARGET) is $1, then return $2, or the empty string otherwise.
qemu2-if-target = $(if $(filter $1,$(QEMU2_TARGET)),$2,$3)

# If $(QEMU2_TARGET_CPU) is $1, then return $2, or the empty string otherwise.
qemu2-if-target-arch = $(if $(filter $1,$(QEMU2_TARGET_CPU)),$2)

$(call start-emulator-program,qemu-system-$(QEMU2_TARGET_SYSTEM))

LOCAL_CFLAGS += \
    $(QEMU2_CFLAGS) \
    $(EMULATOR_LIBUI_CFLAGS)

LOCAL_C_INCLUDES += \
    $(QEMU2_INCLUDES) \
    $(QEMU2_DEPS_TOP_DIR)/include \
    $(call qemu2-if-linux,$(LOCAL_PATH)/linux-headers) \
    $(LOCAL_PATH)/android-qemu2-glue/config/target-$(QEMU2_TARGET) \
    $(LOCAL_PATH)/target-$(QEMU2_TARGET_TARGET) \
    $(LOCAL_PATH)/tcg \
    $(LOCAL_PATH)/tcg/i386 \
    $(LOCAL_PATH)/target-$(QEMU2_TARGET_TARGET) \
    $(ANDROID_EMU_INCLUDES) \
    $(LIBCURL_INCLUDES) \
    $(EMULATOR_LIBUI_INCLUDES) \

LOCAL_CFLAGS += -DNEED_CPU_H

LOCAL_SRC_FILES += \
    android-qemu2-glue/main.cpp \
    $(QEMU2_TARGET_SOURCES) \
    $(QEMU2_TARGET_$(QEMU2_TARGET_CPU)_SOURCES) \
    $(QEMU2_TARGET_$(QEMU2_TARGET_CPU)_SOURCES_$(BUILD_TARGET_TAG))

LOCAL_SRC_FILES += \
    hw/audio/goldfish_audio.c \
    hw/char/goldfish_tty.c \
    hw/display/framebuffer.c \
    hw/display/goldfish_fb.c \
    hw/input/goldfish_events.c \
    hw/intc/goldfish_pic.c \
    hw/misc/android_pipe.c \
    hw/misc/goldfish_battery.c \
    hw/misc/goldfish_sync.c \
    hw/timer/goldfish_timer.c \
    $(call qemu2-if-target,arm arm64,\
        hw/arm/ranchu.c) \
    $(call qemu2-if-target,mips mips64,\
        hw/mips/mips_ranchu.c) \

ifeq (arm64,$(QEMU2_TARGET))
LOCAL_GENERATED_SOURCES += $(QEMU2_AUTO_GENERATED_DIR)/gdbstub-xml-arm64.c
else ifeq (arm,$(QEMU2_TARGET))
LOCAL_GENERATED_SOURCES += $(QEMU2_AUTO_GENERATED_DIR)/gdbstub-xml-arm.c
else
LOCAL_SRC_FILES += stubs/gdbstub.c
endif

LOCAL_SRC_FILES += \
    $(call qemu2-if-target,arm arm64 mips mips64,\
        stubs/dump.c \
        stubs/pci-drive-hot-add.c \
        stubs/qmp_pc_dimm_device_list.c \
        ) \
    $(call qemu2-if-target,mips mips64, \
        stubs/arch-query-cpu-def.c)

LOCAL_PREBUILTS_OBJ_FILES += \
    $(call qemu2-if-windows,$(QEMU2_AUTO_GENERATED_DIR)/version.o)

LOCAL_WHOLE_STATIC_LIBRARIES += \
    libqemu2_common \
    libqemu2_glue \
    $(call qemu2-if-target,arm arm64, libqemu2_common_aarch64) \

LOCAL_STATIC_LIBRARIES += \
    emulator-libui \
    $(EMULATOR_LIBUI_STATIC_LIBRARIES) \
    $(ANDROID_EMU_STATIC_LIBRARIES) \

LOCAL_LDFLAGS += \
    $(QEMU2_DEPS_LDFLAGS) \
    $(EMULATOR_LIBUI_LDFLAGS)

LOCAL_LDLIBS += \
    $(QEMU2_GLIB_LDLIBS) \
    $(QEMU2_PIXMAN_LDLIBS) \
    $(CXX_STD_LIB) \
    -lfdt \
    $(call qemu2-if-windows, -lvfw32) \
    $(call qemu2-if-linux, -lpulse) \
    $(ANDROID_EMU_LDLIBS) \
    $(EMULATOR_LIBUI_LDLIBS) \

LOCAL_INSTALL_DIR := qemu/$(BUILD_TARGET_TAG)

$(call end-emulator-program)
