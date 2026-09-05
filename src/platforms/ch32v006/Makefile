ATOMVM_ROOT := ../../..
.DEFAULT_GOAL := image
.DELETE_ON_ERROR:

ifndef CH32FUN
$(error CH32FUN must point to the ch32fun/ch32fun directory)
endif

TARGET := atomvm_ch32v006
TARGET_MCU := CH32V006
BOARD := uiapduino-pro-micro-ch32v006
FLASH_LIMIT := 63488
MIN_FLASH_HEADROOM ?= 1024
C_STACK_RESERVE_BYTES ?= 1432
MEMORY_PRESSURE_STACK_RESERVE_BYTES ?= 2048
ALLOW_SWIO_PIN ?= 0
CONCURRENCY ?= 0
TIMERS ?= 0
BINARIES ?= 0
MAX_PROCESSES ?= 2
PERIPHERALS ?=
SUPPORTED_PERIPHERALS := gpio_irq uart adc i2c spi pwm
UNKNOWN_PERIPHERALS := $(filter-out $(SUPPORTED_PERIPHERALS),$(PERIPHERALS))
ifneq ($(strip $(UNKNOWN_PERIPHERALS)),)
$(error Unsupported PERIPHERALS value(s): $(UNKNOWN_PERIPHERALS))
endif
BUILD_DIR := build
HOST_JIT_DIR := $(BUILD_DIR)/host-jit
IMAGE_DIR ?= $(BUILD_DIR)/images
RELEASE_DIR ?= $(BUILD_DIR)/release
FLASH_IMAGE ?= $(TARGET).bin
ATOMVM_VERSION ?= $(shell sed -n 's/^set(ATOMVM_BASE_VERSION "\(.*\)")/\1/p' $(ATOMVM_ROOT)/version.cmake)
START_MODULE ?= ch32v006_minimal
START_SOURCE ?= $(START_MODULE).erl
START_BEAM_INPUT ?=
ifneq ($(strip $(START_BEAM_INPUT)),)
START_NAME := $(notdir $(basename $(START_BEAM_INPUT)))
else
START_NAME := $(notdir $(basename $(START_SOURCE)))
endif
PRECOMPILED_BEAM := $(BUILD_DIR)/$(START_NAME).beam
EMBEDDED_BEAM := $(BUILD_DIR)/start.beam
ABI_CANARY_BIN := $(BUILD_DIR)/ch32v006_abi_canary.bin
IMAGE_BASENAME ?= AtomVM-$(BOARD)
RELEASE_BASENAME ?= AtomVM-$(BOARD)-$(ATOMVM_VERSION)
AOT_TARGET := riscv32e+minimal
EXPECTED_JIT_VARIANT := 13

LIBATOMVM_SOURCES := \
    atom.c \
    atom_table.c \
    avmpack.c \
    bif.c \
    bitstring.c \
    context.c \
    defaultatoms.c \
    dist_nifs.c \
    external_term.c \
    globalcontext.c \
    iff.c \
    interop.c \
    intn.c \
    jit.c \
    mailbox.c \
    memory.c \
    module.c \
    refc_binary.c \
    resources.c \
    scheduler.c \
    stacktrace.c \
    term.c \
    timer_list.c \
    unicode.c \
    utils.c \
    valueshashtable.c

ADDITIONAL_C_FILES := \
    abi_canary.c \
    abi_canary.S \
    platform_nifs.c \
    sys.c \
    stdlib.c \
    start_beam.S \
    $(addprefix $(ATOMVM_ROOT)/src/libAtomVM/,$(LIBATOMVM_SOURCES))

ifneq ($(strip $(PERIPHERALS)),)
ADDITIONAL_C_FILES += ch32v006_peripherals.c
EXTRA_CFLAGS += -DAVM_CH32V006_PERIPHERALS
endif

ifneq ($(filter gpio_irq,$(PERIPHERALS)),)
EXTRA_CFLAGS += -DAVM_CH32V006_GPIO_IRQ
endif
ifneq ($(filter uart,$(PERIPHERALS)),)
EXTRA_CFLAGS += -DAVM_CH32V006_UART
endif
ifneq ($(filter adc,$(PERIPHERALS)),)
EXTRA_CFLAGS += -DAVM_CH32V006_ADC
endif
ifneq ($(filter i2c,$(PERIPHERALS)),)
EXTRA_CFLAGS += -DAVM_CH32V006_I2C
endif
ifneq ($(filter spi,$(PERIPHERALS)),)
EXTRA_CFLAGS += -DAVM_CH32V006_SPI
endif
ifneq ($(filter pwm,$(PERIPHERALS)),)
EXTRA_CFLAGS += -DAVM_CH32V006_PWM
endif

EXTRA_CFLAGS += \
    -std=gnu11 \
    -I$(ATOMVM_ROOT)/src/libAtomVM \
    -DAVM_MINIMAL_RUNTIME \
    -DAVM_MINIMAL_BIFS \
    -DAVM_NATIVE_INTERFACE_MINIMAL \
    -DAVM_TEMP_STACK_SIZE=20 \
    -DAVM_NO_EMU \
    -DAVM_NO_SMP \
    -DAVM_CH32V006_STACK_RESERVE_BYTES=$(C_STACK_RESERVE_BYTES) \
    -DNDEBUG \
    -DCONFIG_LOG_LEVEL_MAX=0

ifeq ($(CONCURRENCY),1)
AOT_TARGET := riscv32e+minimal+concurrency
EXPECTED_JIT_VARIANT := 29
EXTRA_CFLAGS += \
    -DAVM_MINIMAL_RUNTIME_CONCURRENCY \
    -DAVM_CH32V006_MAX_PROCESSES=$(MAX_PROCESSES)
endif

ifeq ($(TIMERS),1)
ifneq ($(CONCURRENCY),1)
$(error TIMERS=1 requires CONCURRENCY=1)
endif
AOT_TARGET := riscv32e+minimal+concurrency+timers
EXPECTED_JIT_VARIANT := 61
EXTRA_CFLAGS += -DAVM_MINIMAL_RUNTIME_TIMERS
endif

ifeq ($(BINARIES),1)
ifneq ($(CONCURRENCY),0)
$(error BINARIES=1 cannot currently be combined with CONCURRENCY=1)
endif
AOT_TARGET := riscv32e+minimal+binaries
EXPECTED_JIT_VARIANT := 77
EXTRA_CFLAGS += -DAVM_MINIMAL_RUNTIME_BINARIES
endif

ifeq ($(ALLOW_SWIO_PIN),1)
EXTRA_CFLAGS += -DAVM_CH32V006_ALLOW_SWIO_PIN
endif

ifneq ($(filter ch32v006_self_test ch32v006_gpio_self_test ch32v006_heap_oom_self_test ch32v006_oom_self_test ch32v006_concurrency_self_test ch32v006_timer_self_test ch32v006_binary_self_test ch32v006_binary_oom_self_test ch32v006_concurrency_oom_self_test ch32v006_gpio_irq_self_test ch32v006_uart_self_test ch32v006_adc_self_test ch32v006_i2c_self_test ch32v006_spi_self_test ch32v006_pwm_self_test,$(START_NAME)),)
EXTRA_CFLAGS += -DAVM_CH32V006_SELF_TEST
endif

ifeq ($(START_NAME),ch32v006_oom_self_test)
EXTRA_CFLAGS += -DAVM_CH32V006_OOM_SELF_TEST
endif

ifneq ($(filter ch32v006_oom_self_test ch32v006_binary_oom_self_test ch32v006_concurrency_oom_self_test,$(START_NAME)),)
EXTRA_CFLAGS += -DAVM_CH32V006_ALLOCATOR_FAULT_INJECTION
endif

ifeq ($(START_NAME),ch32v006_binary_oom_self_test)
EXTRA_CFLAGS += -DAVM_CH32V006_BINARY_OOM_SELF_TEST
endif

ifeq ($(START_NAME),ch32v006_concurrency_oom_self_test)
EXTRA_CFLAGS += -DAVM_CH32V006_CONCURRENCY_OOM_SELF_TEST
endif

EXTRA_ELF_DEPENDENCIES := $(EMBEDDED_BEAM) $(ABI_CANARY_BIN)

JIT_ERLANG_SOURCES := \
    ch32v006_abi_canary_gen.erl \
    ch32v006_negative_tests.erl \
    ch32v006_validate.erl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_regs.erl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_stream_binary.erl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_riscv32_asm.erl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_riscv32.erl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_riscv32e.erl \
    $(ATOMVM_ROOT)/libs/jit/src/jit.erl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_precompile.erl

JIT_ERLANG_DEPENDENCIES := \
    $(JIT_ERLANG_SOURCES) \
    $(ATOMVM_ROOT)/libs/jit/include/jit.hrl \
    $(ATOMVM_ROOT)/libs/jit/src/compact_term.hrl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_backend_regs_impl.hrl \
    $(ATOMVM_ROOT)/libs/jit/src/jit_riscv_impl.hrl \
    $(ATOMVM_ROOT)/libs/jit/src/primitives.hrl

$(HOST_JIT_DIR)/.stamp: $(JIT_ERLANG_DEPENDENCIES)
	mkdir -p $(HOST_JIT_DIR)
	erlc -I $(ATOMVM_ROOT)/libs/jit/include -I $(ATOMVM_ROOT)/libs/jit/src \
	    -o $(HOST_JIT_DIR) $(JIT_ERLANG_SOURCES)
	touch $@

$(ABI_CANARY_BIN): $(HOST_JIT_DIR)/.stamp
	mkdir -p $(BUILD_DIR)
	erl -pa $(HOST_JIT_DIR) -noshell \
	    -eval 'ok = ch32v006_abi_canary_gen:generate("$@"), halt().'

ifneq ($(strip $(START_BEAM_INPUT)),)
$(PRECOMPILED_BEAM): $(START_BEAM_INPUT) $(HOST_JIT_DIR)/.stamp
	mkdir -p $(BUILD_DIR)
	cp $< $@
	erl -pa $(HOST_JIT_DIR) -noshell \
	    -eval 'jit_precompile:compile("$(AOT_TARGET)", "$(BUILD_DIR)", false, "$@"), halt().'
	erl -pa $(HOST_JIT_DIR) -noshell \
	    -eval 'ok = ch32v006_validate:validate_beam("$@", $(EXPECTED_JIT_VARIANT)), halt().'
else
$(PRECOMPILED_BEAM): $(START_SOURCE) $(HOST_JIT_DIR)/.stamp
	mkdir -p $(BUILD_DIR)
	erlc +debug_info -o $(BUILD_DIR) $<
	erl -pa $(HOST_JIT_DIR) -noshell \
	    -eval 'jit_precompile:compile("$(AOT_TARGET)", "$(BUILD_DIR)", false, "$@"), halt().'
	erl -pa $(HOST_JIT_DIR) -noshell \
	    -eval 'ok = ch32v006_validate:validate_beam("$@", $(EXPECTED_JIT_VARIANT)), halt().'
endif

$(EMBEDDED_BEAM): $(PRECOMPILED_BEAM) FORCE
	cp $< $@

.PHONY: build image verify-image release-image acceptance-images concurrency-image concurrency-memory-image concurrency-oom-image timer-image timer-memory-image binary-image binary-oom-image peripheral-images validation-tests flash-uiap monitor-uiap clean help FORCE
FORCE:

build: $(TARGET).bin

verify-image: build
	@flash_bytes=$$(wc -c < $(TARGET).bin); \
	flash_budget=$$(( $(FLASH_LIMIT) - $(MIN_FLASH_HEADROOM) )); \
	if [ "$$flash_bytes" -gt "$$flash_budget" ]; then \
	    echo "Image leaves less than $(MIN_FLASH_HEADROOM) bytes headroom: $$flash_bytes / $(FLASH_LIMIT) bytes"; \
	    exit 1; \
	fi; \
	echo "Verified $(TARGET).bin: $$flash_bytes / $(FLASH_LIMIT) bytes ($$(( $(FLASH_LIMIT) - flash_bytes )) bytes free)"
	@riscv64-unknown-elf-readelf -h $(TARGET).elf | grep -Fq 'RISC-V'
	@riscv64-unknown-elf-readelf -h $(TARGET).elf | grep -Fq 'RVE'

image: verify-image
	mkdir -p $(IMAGE_DIR)
	cp $(TARGET).bin $(IMAGE_DIR)/$(IMAGE_BASENAME).bin
	cp $(TARGET).hex $(IMAGE_DIR)/$(IMAGE_BASENAME).hex
	cp $(TARGET).elf $(IMAGE_DIR)/$(IMAGE_BASENAME).elf
	cd $(IMAGE_DIR) && sha256sum $(IMAGE_BASENAME).bin > $(IMAGE_BASENAME).bin.sha256

release-image: verify-image
	mkdir -p $(RELEASE_DIR)
	cp $(TARGET).bin $(RELEASE_DIR)/$(RELEASE_BASENAME).bin
	cd $(RELEASE_DIR) && sha256sum $(RELEASE_BASENAME).bin > $(RELEASE_BASENAME).bin.sha256

acceptance-images:
	$(MAKE) START_SOURCE=$(CURDIR)/ch32v006_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-language-self-test image
	$(MAKE) -B START_SOURCE=$(CURDIR)/ch32v006_self_test.erl \
	    C_STACK_RESERVE_BYTES=$(MEMORY_PRESSURE_STACK_RESERVE_BYTES) \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-memory-pressure-self-test image
	$(MAKE) START_SOURCE=$(CURDIR)/ch32v006_gpio_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-gpio-self-test image
	$(MAKE) START_SOURCE=$(CURDIR)/ch32v006_oom_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-oom-self-test image
	$(MAKE) START_SOURCE=$(CURDIR)/ch32v006_heap_oom_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-heap-oom-self-test image
	$(MAKE) START_SOURCE=$(CURDIR)/ch32v006_minimal.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD) image

concurrency-image:
	$(MAKE) -B CONCURRENCY=1 \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_concurrency_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-concurrency-self-test image

concurrency-memory-image:
	$(MAKE) -B CONCURRENCY=1 \
	    C_STACK_RESERVE_BYTES=$(MEMORY_PRESSURE_STACK_RESERVE_BYTES) \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_concurrency_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-concurrency-memory-pressure-self-test image

concurrency-oom-image:
	$(MAKE) -B CONCURRENCY=1 \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_concurrency_oom_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-concurrency-oom-self-test image

timer-image:
	$(MAKE) -B CONCURRENCY=1 TIMERS=1 \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_timer_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-timer-self-test image

timer-memory-image:
	$(MAKE) -B CONCURRENCY=1 TIMERS=1 \
	    C_STACK_RESERVE_BYTES=$(MEMORY_PRESSURE_STACK_RESERVE_BYTES) \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_timer_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-timer-memory-pressure-self-test image

binary-image:
	$(MAKE) -B BINARIES=1 \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_binary_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-binary-self-test image

binary-oom-image:
	$(MAKE) -B BINARIES=1 \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_binary_oom_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-binary-oom-self-test image

peripheral-images:
	$(MAKE) -B PERIPHERALS=gpio_irq \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_gpio_irq_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-gpio-irq-self-test image
	$(MAKE) -B PERIPHERALS=uart \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_uart_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-uart-self-test image
	$(MAKE) -B PERIPHERALS=adc \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_adc_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-adc-self-test image
	$(MAKE) -B PERIPHERALS=i2c \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_i2c_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-i2c-self-test image
	$(MAKE) -B PERIPHERALS=spi \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_spi_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-spi-self-test image
	$(MAKE) -B PERIPHERALS=pwm \
	    START_SOURCE=$(CURDIR)/tests/ch32v006_pwm_self_test.erl \
	    IMAGE_BASENAME=AtomVM-$(BOARD)-pwm-self-test image

validation-tests: $(HOST_JIT_DIR)/.stamp
	erlc -I $(ATOMVM_ROOT)/libs/jit/include -o $(HOST_JIT_DIR) ch32v006_validate_tests.erl
	erl -pa $(HOST_JIT_DIR) -noshell \
	    -eval 'ok = ch32v006_validate_tests:run(), halt().'
	mkdir -p $(BUILD_DIR)/unsupported
	erl -pa $(HOST_JIT_DIR) -noshell \
	    -eval 'ok = ch32v006_negative_tests:run("$(CURDIR)/tests/unsupported", "$(BUILD_DIR)/unsupported"), halt().'

flash-uiap:
	@test -x "$(MINICHLINK)/minichlink" || \
	    { echo "MINICHLINK must point to the ch32fun/minichlink directory"; exit 1; }
	@test -f "$(FLASH_IMAGE)" || \
	    { echo "FLASH_IMAGE does not exist: $(FLASH_IMAGE)"; exit 1; }
	$(MINICHLINK)/minichlink -c 0x1209b806 -C funprog -w $(FLASH_IMAGE) flash -b

monitor-uiap:
	@test -x "$(MINICHLINK)/minichlink" || \
	    { echo "MINICHLINK must point to the ch32fun/minichlink directory"; exit 1; }
	$(MINICHLINK)/minichlink -c 0x1209b806 -C funprog -T

clean:
	$(RM) -r $(BUILD_DIR)
	$(RM) $(TARGET).bin $(TARGET).elf $(TARGET).hex $(TARGET).lst $(TARGET).map $(TARGET)_ext.bin

help:
	@echo "Targets:"
	@echo "  image              Build a distributable BIN/HEX/ELF image set (default)"
	@echo "  release-image      Build a versioned BIN image and SHA-256 file"
	@echo "  acceptance-images  Build language, GPIO, and default image sets"
	@echo "  concurrency-image  Build the experimental two-process acceptance image"
	@echo "  concurrency-memory-image  Build the two-process memory-pressure image"
	@echo "  concurrency-oom-image  Build the spawn allocation-failure image"
	@echo "  timer-image        Build the experimental receive-timeout acceptance image"
	@echo "  timer-memory-image  Build the timer memory-pressure image"
	@echo "  binary-image       Build the experimental byte-binary acceptance image"
	@echo "  binary-oom-image   Build the binary-allocation failure acceptance image"
	@echo "  peripheral-images  Build each experimental peripheral image independently"
	@echo "  validation-tests   Check the CH32V006 native-code validator"
	@echo "  flash-uiap         Flash the current image through the UIAP programmer"
	@echo "  monitor-uiap       Open the UIAP SWIO terminal"
	@echo "Variables: CH32FUN, MINICHLINK, START_SOURCE, START_BEAM_INPUT, FLASH_IMAGE, ATOMVM_VERSION, C_STACK_RESERVE_BYTES, MEMORY_PRESSURE_STACK_RESERVE_BYTES, MIN_FLASH_HEADROOM, ALLOW_SWIO_PIN, CONCURRENCY, TIMERS, BINARIES, MAX_PROCESSES, PERIPHERALS"

include $(CH32FUN)/ch32fun.mk
