/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#include "ch32v006_peripherals.h"
#include "ch32v006_pins.h"

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include <ch32fun.h>

#include <context.h>
#include <defaultatoms.h>
#include <interop.h>
#include <memory.h>
#include <term.h>
#include <utils.h>

#define CH32V006_IO_TIMEOUT_MS 10U
#define CH32V006_IO_TIMEOUT_TICKS (DELAY_MS_TIME * CH32V006_IO_TIMEOUT_MS)
#define CH32V006_MAX_IO_BYTES 64U

#if defined(AVM_CH32V006_UART) || defined(AVM_CH32V006_ADC) \
    || defined(AVM_CH32V006_I2C) || defined(AVM_CH32V006_SPI)
static bool io_timeout_expired(uint32_t start_ticks)
{
    return TimeElapsed32u(funSysTick32(), start_ticks) >= CH32V006_IO_TIMEOUT_TICKS;
}
#endif

#if defined(AVM_CH32V006_UART) || defined(AVM_CH32V006_ADC)
static bool wait_register_set32(volatile uint32_t *reg, uint32_t mask)
{
    uint32_t start_ticks = funSysTick32();
    while ((*reg & mask) == 0U) {
        if (io_timeout_expired(start_ticks)) {
            return false;
        }
    }
    return true;
}

static bool wait_register_clear32(volatile uint32_t *reg, uint32_t mask)
{
    uint32_t start_ticks = funSysTick32();
    while ((*reg & mask) != 0U) {
        if (io_timeout_expired(start_ticks)) {
            return false;
        }
    }
    return true;
}
#endif

#if defined(AVM_CH32V006_I2C) || defined(AVM_CH32V006_SPI)
static bool wait_register_set16(volatile uint16_t *reg, uint16_t mask)
{
    uint32_t start_ticks = funSysTick32();
    while ((*reg & mask) == 0U) {
        if (io_timeout_expired(start_ticks)) {
            return false;
        }
    }
    return true;
}

static bool wait_register_clear16(volatile uint16_t *reg, uint16_t mask)
{
    uint32_t start_ticks = funSysTick32();
    while ((*reg & mask) != 0U) {
        if (io_timeout_expired(start_ticks)) {
            return false;
        }
    }
    return true;
}
#endif

#define DEFINE_NIF(name)                                          \
    static const struct Nif name##_nif                            \
        __attribute__((section(".rodata.ch32v006_nifs")))         \
        = {                                                       \
              .base.type = NIFFunctionType, .nif_ptr = nif_##name \
          }

#if defined(AVM_CH32V006_I2C) || defined(AVM_CH32V006_SPI)
static term make_binary(Context *ctx, size_t size, uint8_t **data)
{
    if (size > CH32V006_MAX_IO_BYTES
        || memory_ensure_free_opt(ctx, term_binary_heap_size(size), MEMORY_CAN_SHRINK) != MEMORY_GC_OK) {
        return term_invalid_term();
    }

    term binary = term_create_uninitialized_binary(size, &ctx->heap, ctx->global);
    *data = (uint8_t *) term_binary_data(binary);
    return binary;
}
#endif

#ifdef AVM_CH32V006_UART
static void uart1_init(uint32_t baud)
{
    RCC->APB2PCENR |= RCC_APB2Periph_AFIO | RCC_APB2Periph_GPIOD | RCC_APB2Periph_USART1;
    AFIO->PCFR1 &= ~AFIO_PCFR1_USART1_RM;
    funPinMode(PD5, GPIO_CFGLR_OUT_10Mhz_AF_PP);
    funPinMode(PD6, GPIO_CFGLR_IN_FLOAT);

    RCC->PB2PRSTR |= RCC_USART1RST;
    RCC->PB2PRSTR &= ~RCC_USART1RST;

    USART1->CTLR1 = 0;
    USART1->CTLR2 = USART_StopBits_1;
    USART1->CTLR3 = 0;
    USART1->BRR = (FUNCONF_SYSTEM_CORE_CLOCK + (baud / 2U)) / baud;
    USART1->CTLR1 = USART_Mode_Tx | USART_Mode_Rx | USART_CTLR1_UE;
}

static term nif_uart_init(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_integer(argv[0])) {
        return term_invalid_term();
    }
    avm_int_t baud = term_to_int(argv[0]);
    if (baud <= 0 || baud > 2000000) {
        return term_invalid_term();
    }
    uart1_init((uint32_t) baud);
    return OK_ATOM;
}

static term nif_uart_write(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_binary(argv[0])) {
        return term_invalid_term();
    }
    size_t size = term_binary_size(argv[0]);
    if (size > CH32V006_MAX_IO_BYTES) {
        return term_invalid_term();
    }
    const uint8_t *data = (const uint8_t *) term_binary_data(argv[0]);
    for (size_t i = 0; i < size; ++i) {
        if (!wait_register_set32(&USART1->STATR, USART_STATR_TXE)) {
            return ERROR_ATOM;
        }
        USART1->DATAR = data[i];
    }

    return wait_register_set32(&USART1->STATR, USART_STATR_TC)
        ? term_from_int((avm_int_t) size)
        : ERROR_ATOM;
}

static term nif_uart_read(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    UNUSED(argv);
    if (argc != 0) {
        return term_invalid_term();
    }
    if ((USART1->STATR & USART_STATR_RXNE) == 0U) {
        return UNDEFINED_ATOM;
    }
    return term_from_int((avm_int_t) (USART1->DATAR & 0xFFU));
}

DEFINE_NIF(uart_init);
DEFINE_NIF(uart_write);
DEFINE_NIF(uart_read);
#endif

#ifdef AVM_CH32V006_ADC
static const uint8_t adc_pins[8] = {
    PA2, PA1, PC4, PD2, PD3, PD5, PD6, PD4
};

static bool adc_initialized;

static bool adc_init(void)
{
    RCC->CFGR0 = (RCC->CFGR0 & ~(RCC_ADCPRE | RCC_CFGR0_ADC_CLK_MODE | RCC_CFGR0_ADC_CLK_ADJ))
        | RCC_ADCPRE_DIV2;
    RCC->PB2PCENR |= RCC_ADCEN | RCC_IOPAEN | RCC_IOPCEN | RCC_IOPDEN;
    RCC->PB2PRSTR |= RCC_ADC1RST;
    RCC->PB2PRSTR &= ~RCC_ADC1RST;
    ADC1->CTLR1 = 0;
    ADC1->CTLR2 = 0;
    ADC1->RSQR1 = 0;
    ADC1->RSQR2 = 0;

    // Power up first, then allow the ADC's 1 us stabilization interval.
    ADC1->CTLR2 |= ADC_ADON;
    Delay_Us(1);

    // Select and enable the software trigger for the regular conversion group.
    ADC1->CTLR2 |= ADC_EXTSEL_SWSTART | ADC_EXTTRIG;

    // Follow the CH32V00x startup sequence and calibrate once after power-up.
    ADC1->CTLR2 |= ADC_RSTCAL;
    if (!wait_register_clear32(&ADC1->CTLR2, ADC_RSTCAL)) {
        return false;
    }
    ADC1->CTLR2 |= ADC_CAL;
    if (!wait_register_clear32(&ADC1->CTLR2, ADC_CAL)) {
        return false;
    }

    return true;
}

static term nif_adc_read(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_integer(argv[0])) {
        return term_invalid_term();
    }
    avm_int_t channel = term_to_int(argv[0]);
    if (channel < 0 || channel > 7) {
        return term_invalid_term();
    }
    if (!adc_initialized) {
        if (!adc_init()) {
            return ERROR_ATOM;
        }
        adc_initialized = true;
    }

    funPinMode(adc_pins[channel], GPIO_CFGLR_IN_ANALOG);
    ADC1->RSQR3 = (uint32_t) channel;
    ADC1->SAMPTR2 &= ~(ADC_SMP0 << (3U * (uint32_t) channel));
    ADC1->SAMPTR2 |= 7U << (3U * (uint32_t) channel);
    ADC1->CTLR2 |= ADC_SWSTART;

    if (!wait_register_set32(&ADC1->STATR, ADC_EOC)) {
        return ERROR_ATOM;
    }
    return term_from_int((avm_int_t) ADC1->RDATAR);
}

DEFINE_NIF(adc_read);
#endif

#ifdef AVM_CH32V006_I2C
#ifndef I2C_EVENT_MASTER_TRANSMITTER_SELECTED
#define I2C_EVENT_MASTER_TRANSMITTER_SELECTED UINT32_C(0x00070082)
#endif
#ifndef I2C_EVENT_MASTER_RECEIVER_SELECTED
#define I2C_EVENT_MASTER_RECEIVER_SELECTED UINT32_C(0x00030002)
#endif

static uint32_t i2c_clock_hz;

static void i2c_setup(uint32_t clock_hz);

static void i2c_recover(void)
{
    if (i2c_clock_hz != 0U) {
        i2c_setup(i2c_clock_hz);
    }
}

static uint32_t i2c_event(void)
{
    uint32_t status1 = I2C1->STAR1;
    uint32_t status2 = I2C1->STAR2;
    return status1 | (status2 << 16);
}

static bool i2c_wait_event(uint32_t event)
{
    uint32_t start_ticks = funSysTick32();
    while ((i2c_event() & event) != event) {
        if ((I2C1->STAR1 & I2C_STAR1_AF) != 0U) {
            I2C1->STAR1 &= ~I2C_STAR1_AF;
            return false;
        }
        if (io_timeout_expired(start_ticks)) {
            i2c_recover();
            return false;
        }
    }
    return true;
}

static bool i2c_wait_idle(void)
{
    if (!wait_register_clear16(&I2C1->STAR2, I2C_STAR2_BUSY)) {
        i2c_recover();
        return false;
    }
    return true;
}

static void i2c_stop(void)
{
    I2C1->CTLR1 |= I2C_CTLR1_STOP;
    I2C1->STAR1 &= ~I2C_STAR1_AF;
}

static void i2c_setup(uint32_t clock_hz)
{
    i2c_clock_hz = clock_hz;
    RCC->APB1PCENR |= RCC_APB1Periph_I2C1;
    RCC->APB2PCENR |= RCC_APB2Periph_GPIOC | RCC_APB2Periph_AFIO;
    funPinMode(PC1, GPIO_CFGLR_OUT_10Mhz_AF_OD);
    funPinMode(PC2, GPIO_CFGLR_OUT_10Mhz_AF_OD);
    AFIO->PCFR1 &= ~AFIO_PCFR1_I2C1_RM;

    RCC->PB1PRSTR |= RCC_I2C1RST;
    RCC->PB1PRSTR &= ~RCC_I2C1RST;
    I2C1->CTLR1 |= I2C_CTLR1_SWRST;
    I2C1->CTLR1 &= ~I2C_CTLR1_SWRST;

    uint32_t peripheral_clock_mhz = FUNCONF_SYSTEM_CORE_CLOCK / 1000000U;
    I2C1->CTLR2 = (I2C1->CTLR2 & ~I2C_CTLR2_FREQ) | (peripheral_clock_mhz & I2C_CTLR2_FREQ);

    if (clock_hz <= 100000U) {
        I2C1->CKCFGR = (FUNCONF_SYSTEM_CORE_CLOCK / (2U * clock_hz)) & I2C_CKCFGR_CCR;
    } else {
        uint32_t ccr = FUNCONF_SYSTEM_CORE_CLOCK / (3U * clock_hz);
        I2C1->CKCFGR = (ccr & I2C_CKCFGR_CCR) | I2C_CKCFGR_FS;
    }
    I2C1->CTLR1 = I2C_CTLR1_PE | I2C_CTLR1_ACK;
}

static bool i2c_start_address(uint8_t address, bool read)
{
    if (!i2c_wait_idle()) {
        return false;
    }
    I2C1->CTLR1 |= I2C_CTLR1_START;
    if (!i2c_wait_event(I2C_EVENT_MASTER_MODE_SELECT)) {
        return false;
    }
    I2C1->DATAR = ((uint32_t) address << 1) | (read ? 1U : 0U);
    return i2c_wait_event(read ? I2C_EVENT_MASTER_RECEIVER_SELECTED : I2C_EVENT_MASTER_TRANSMITTER_SELECTED);
}

static bool i2c_write_bytes(uint8_t address, const uint8_t *data, size_t size)
{
    if (!i2c_start_address(address, false)) {
        i2c_stop();
        return false;
    }
    for (size_t i = 0; i < size; ++i) {
        if (!wait_register_set16(&I2C1->STAR1, I2C_STAR1_TXE)) {
            i2c_stop();
            i2c_recover();
            return false;
        }
        I2C1->DATAR = data[i];
    }
    if (!i2c_wait_event(I2C_EVENT_MASTER_BYTE_TRANSMITTED)) {
        i2c_stop();
        return false;
    }
    i2c_stop();
    return true;
}

static bool i2c_start_read_address(uint8_t address)
{
    if (!i2c_wait_idle()) {
        return false;
    }
    I2C1->CTLR1 |= I2C_CTLR1_START;
    if (!i2c_wait_event(I2C_EVENT_MASTER_MODE_SELECT)) {
        return false;
    }
    I2C1->DATAR = ((uint32_t) address << 1) | 1U;

    uint32_t start_ticks = funSysTick32();
    while ((I2C1->STAR1 & I2C_STAR1_ADDR) == 0U) {
        if ((I2C1->STAR1 & I2C_STAR1_AF) != 0U) {
            I2C1->STAR1 &= ~I2C_STAR1_AF;
            return false;
        }
        if (io_timeout_expired(start_ticks)) {
            i2c_recover();
            return false;
        }
    }
    return true;
}

static bool i2c_wait_status1(uint32_t mask)
{
    if (!wait_register_set16(&I2C1->STAR1, (uint16_t) mask)) {
        i2c_recover();
        return false;
    }
    return true;
}

static void i2c_clear_addr(void)
{
    (void) I2C1->STAR1;
    (void) I2C1->STAR2;
}

static bool i2c_read_bytes(uint8_t address, uint8_t *data, size_t size)
{
    if (size == 0U) {
        return true;
    }

    I2C1->CTLR1 &= ~I2C_CTLR1_POS;
    if (size == 1U) {
        I2C1->CTLR1 &= ~I2C_CTLR1_ACK;
    } else {
        I2C1->CTLR1 |= I2C_CTLR1_ACK;
    }
    if (!i2c_start_read_address(address)) {
        i2c_stop();
        I2C1->CTLR1 |= I2C_CTLR1_ACK;
        return false;
    }

    if (size == 1U) {
        i2c_clear_addr();
        i2c_stop();
        if (!i2c_wait_status1(I2C_STAR1_RXNE)) {
            I2C1->CTLR1 |= I2C_CTLR1_ACK;
            return false;
        }
        data[0] = (uint8_t) I2C1->DATAR;
        I2C1->CTLR1 |= I2C_CTLR1_ACK;
        return true;
    }

    if (size == 2U) {
        I2C1->CTLR1 |= I2C_CTLR1_POS;
        I2C1->CTLR1 &= ~I2C_CTLR1_ACK;
        i2c_clear_addr();
        if (!i2c_wait_status1(I2C_STAR1_BTF)) {
            i2c_stop();
            I2C1->CTLR1 &= ~I2C_CTLR1_POS;
            I2C1->CTLR1 |= I2C_CTLR1_ACK;
            return false;
        }
        i2c_stop();
        data[0] = (uint8_t) I2C1->DATAR;
        data[1] = (uint8_t) I2C1->DATAR;
        I2C1->CTLR1 &= ~I2C_CTLR1_POS;
        I2C1->CTLR1 |= I2C_CTLR1_ACK;
        return true;
    }

    i2c_clear_addr();
    size_t index = 0;
    size_t remaining = size;
    while (remaining > 3U) {
        if (!i2c_wait_status1(I2C_STAR1_RXNE)) {
            i2c_stop();
            return false;
        }
        data[index++] = (uint8_t) I2C1->DATAR;
        --remaining;
    }

    if (!i2c_wait_status1(I2C_STAR1_BTF)) {
        i2c_stop();
        return false;
    }
    I2C1->CTLR1 &= ~I2C_CTLR1_ACK;
    data[index++] = (uint8_t) I2C1->DATAR;
    --remaining;

    if (!i2c_wait_status1(I2C_STAR1_BTF)) {
        i2c_stop();
        I2C1->CTLR1 |= I2C_CTLR1_ACK;
        return false;
    }
    i2c_stop();
    data[index++] = (uint8_t) I2C1->DATAR;
    --remaining;
    data[index] = (uint8_t) I2C1->DATAR;
    I2C1->CTLR1 |= I2C_CTLR1_ACK;
    return remaining == 1U;
}

static term nif_i2c_init(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_integer(argv[0])) {
        return term_invalid_term();
    }
    avm_int_t clock_hz = term_to_int(argv[0]);
    if (clock_hz < 10000 || clock_hz > 400000) {
        return term_invalid_term();
    }
    i2c_setup((uint32_t) clock_hz);
    return OK_ATOM;
}

static term nif_i2c_probe(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_integer(argv[0])) {
        return term_invalid_term();
    }
    avm_int_t address = term_to_int(argv[0]);
    if (address < 0x08 || address > 0x77) {
        return term_invalid_term();
    }
    bool success = i2c_start_address((uint8_t) address, false);
    i2c_stop();
    return success ? OK_ATOM : ERROR_ATOM;
}

static term nif_i2c_write(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 2 || !term_is_integer(argv[0]) || !term_is_binary(argv[1])) {
        return term_invalid_term();
    }
    avm_int_t address = term_to_int(argv[0]);
    size_t size = term_binary_size(argv[1]);
    if (address < 0x08 || address > 0x77 || size > CH32V006_MAX_IO_BYTES) {
        return term_invalid_term();
    }
    return i2c_write_bytes((uint8_t) address, (const uint8_t *) term_binary_data(argv[1]), size)
        ? term_from_int((avm_int_t) size)
        : ERROR_ATOM;
}

static term nif_i2c_read(Context *ctx, int argc, term argv[])
{
    if (argc != 2 || !term_is_integer(argv[0]) || !term_is_integer(argv[1])) {
        return term_invalid_term();
    }
    avm_int_t address = term_to_int(argv[0]);
    avm_int_t count = term_to_int(argv[1]);
    if (address < 0x08 || address > 0x77 || count < 0 || count > (avm_int_t) CH32V006_MAX_IO_BYTES) {
        return term_invalid_term();
    }

    uint8_t *data;
    term binary = make_binary(ctx, (size_t) count, &data);
    if (term_is_invalid_term(binary)) {
        return binary;
    }
    return i2c_read_bytes((uint8_t) address, data, (size_t) count) ? binary : ERROR_ATOM;
}

DEFINE_NIF(i2c_init);
DEFINE_NIF(i2c_probe);
DEFINE_NIF(i2c_write);
DEFINE_NIF(i2c_read);
#endif

#ifdef AVM_CH32V006_SPI
static void spi_setup(uint32_t clock_hz, uint32_t mode)
{
    RCC->APB2PCENR |= RCC_APB2Periph_GPIOC | RCC_APB2Periph_AFIO | RCC_APB2Periph_SPI1;
    AFIO->PCFR1 &= ~AFIO_PCFR1_SPI1_RM;
    funPinMode(PC5, GPIO_CFGLR_OUT_50Mhz_AF_PP);
    funPinMode(PC6, GPIO_CFGLR_OUT_50Mhz_AF_PP);
    funPinMode(PC7, GPIO_CFGLR_IN_FLOAT);

    RCC->PB2PRSTR |= RCC_SPI1RST;
    RCC->PB2PRSTR &= ~RCC_SPI1RST;

    uint32_t divider = 2U;
    uint32_t br = 0U;
    while ((FUNCONF_SYSTEM_CORE_CLOCK / divider) > clock_hz && divider < 256U) {
        divider <<= 1;
        ++br;
    }

    SPI1->CTLR1 = SPI_NSS_Soft | SPI_Mode_Master | SPI_Direction_2Lines_FullDuplex
        | SPI_DataSize_8b | ((br << 3) & SPI_CTLR1_BR);
    if (mode & 2U) {
        SPI1->CTLR1 |= SPI_CPOL_High;
    } else {
        SPI1->CTLR1 |= SPI_CPOL_Low;
    }
    if (mode & 1U) {
        SPI1->CTLR1 |= SPI_CPHA_2Edge;
    } else {
        SPI1->CTLR1 |= SPI_CPHA_1Edge;
    }
    SPI1->CTLR1 |= SPI_CTLR1_SPE;
}

static term nif_spi_init(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 2 || !term_is_integer(argv[0]) || !term_is_integer(argv[1])) {
        return term_invalid_term();
    }
    avm_int_t clock_hz = term_to_int(argv[0]);
    avm_int_t mode = term_to_int(argv[1]);
    if (clock_hz < (avm_int_t) (FUNCONF_SYSTEM_CORE_CLOCK / 256U)
        || clock_hz > (avm_int_t) (FUNCONF_SYSTEM_CORE_CLOCK / 2U)
        || mode < 0 || mode > 3) {
        return term_invalid_term();
    }
    spi_setup((uint32_t) clock_hz, (uint32_t) mode);
    return OK_ATOM;
}

static term nif_spi_transfer(Context *ctx, int argc, term argv[])
{
    if (argc != 1 || !term_is_binary(argv[0])) {
        return term_invalid_term();
    }
    size_t size = term_binary_size(argv[0]);
    if (size > CH32V006_MAX_IO_BYTES) {
        return term_invalid_term();
    }
    const uint8_t *tx = (const uint8_t *) term_binary_data(argv[0]);
    uint8_t *rx;
    term binary = make_binary(ctx, size, &rx);
    if (term_is_invalid_term(binary)) {
        return binary;
    }

    for (size_t i = 0; i < size; ++i) {
        if (!wait_register_set16(&SPI1->STATR, SPI_STATR_TXE)) {
            return ERROR_ATOM;
        }
        SPI1->DATAR = tx[i];
        if (!wait_register_set16(&SPI1->STATR, SPI_STATR_RXNE)) {
            return ERROR_ATOM;
        }
        rx[i] = (uint8_t) SPI1->DATAR;
    }

    return wait_register_clear16(&SPI1->STATR, SPI_STATR_BSY) ? binary : ERROR_ATOM;
}

static term nif_spi_transfer_byte(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_integer(argv[0])) {
        return term_invalid_term();
    }
    avm_int_t value = term_to_int(argv[0]);
    if (value < 0 || value > UINT8_MAX) {
        return term_invalid_term();
    }
    if (!wait_register_set16(&SPI1->STATR, SPI_STATR_TXE)) {
        return ERROR_ATOM;
    }
    SPI1->DATAR = (uint8_t) value;
    if (!wait_register_set16(&SPI1->STATR, SPI_STATR_RXNE)) {
        return ERROR_ATOM;
    }
    uint8_t received = (uint8_t) SPI1->DATAR;
    return wait_register_clear16(&SPI1->STATR, SPI_STATR_BSY)
        ? term_from_int(received)
        : ERROR_ATOM;
}

DEFINE_NIF(spi_init);
DEFINE_NIF(spi_transfer);
DEFINE_NIF(spi_transfer_byte);
#endif

#ifdef AVM_CH32V006_PWM
static uint32_t pwm_period;

static term nif_pwm_init(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_integer(argv[0])) {
        return term_invalid_term();
    }
    avm_int_t frequency_hz = term_to_int(argv[0]);
    if (frequency_hz <= 0 || frequency_hz > 50000) {
        return term_invalid_term();
    }

    uint32_t ticks = FUNCONF_SYSTEM_CORE_CLOCK / (uint32_t) frequency_hz;
    uint32_t prescaler = (ticks + 65535U) / 65536U;
    if (prescaler == 0U) {
        prescaler = 1U;
    }
    if (prescaler > 65536U) {
        return term_invalid_term();
    }
    pwm_period = ticks / prescaler;
    if (pwm_period < 2U || pwm_period > 65536U) {
        return term_invalid_term();
    }

    RCC->APB2PCENR |= RCC_APB2Periph_GPIOC | RCC_APB2Periph_AFIO | RCC_APB2Periph_TIM1;
    AFIO->PCFR1 &= ~AFIO_PCFR1_TIM1_RM;
    funPinMode(PC3, GPIO_CFGLR_OUT_10Mhz_AF_PP);
    funPinMode(PC4, GPIO_CFGLR_OUT_10Mhz_AF_PP);
    RCC->APB2PRSTR |= RCC_APB2Periph_TIM1;
    RCC->APB2PRSTR &= ~RCC_APB2Periph_TIM1;

    TIM1->PSC = prescaler - 1U;
    TIM1->ATRLR = pwm_period - 1U;
    TIM1->CHCTLR2 = TIM1_CHCTLR2_OC3M_2 | TIM1_CHCTLR2_OC3M_1
        | TIM1_CHCTLR2_OC4M_2 | TIM1_CHCTLR2_OC4M_1;
    TIM1->CCER |= TIM1_CCER_CC3E | TIM1_CCER_CC4E;
    TIM1->CH3CVR = 0;
    TIM1->CH4CVR = 0;
    TIM1->BDTR |= TIM1_BDTR_MOE;
    TIM1->SWEVGR |= TIM1_SWEVGR_UG;
    TIM1->CTLR1 |= TIM1_CTLR1_CEN;
    return OK_ATOM;
}

static term nif_pwm_set_duty(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 2 || !term_is_integer(argv[0]) || !term_is_integer(argv[1]) || pwm_period == 0U) {
        return term_invalid_term();
    }
    avm_int_t channel = term_to_int(argv[0]);
    avm_int_t duty = term_to_int(argv[1]);
    if ((channel != 3 && channel != 4) || duty < 0 || duty > 1000) {
        return term_invalid_term();
    }
    uint32_t compare = (pwm_period * (uint32_t) duty) / 1000U;
    if (channel == 3) {
        TIM1->CH3CVR = compare;
    } else {
        TIM1->CH4CVR = compare;
    }
    return OK_ATOM;
}

DEFINE_NIF(pwm_init);
DEFINE_NIF(pwm_set_duty);
#endif

#ifdef AVM_CH32V006_GPIO_IRQ
static volatile uint8_t gpio_irq_pending;

enum
{
    GPIOInterruptRising,
    GPIOInterruptFalling,
    GPIOInterruptBoth
};

static const AtomStringIntPair interrupt_edge_table[] = {
    { ATOM_STR("\x6", "rising"), GPIOInterruptRising },
    { ATOM_STR("\x7", "falling"), GPIOInterruptFalling },
    { ATOM_STR("\x4", "both"), GPIOInterruptBoth },
    SELECT_INT_DEFAULT(-1)
};

static void gpio_irq_clear_pending(uint32_t line)
{
    NVIC_DisableIRQ(EXTI7_0_IRQn);
    gpio_irq_pending &= (uint8_t) ~line;
    NVIC_EnableIRQ(EXTI7_0_IRQn);
}

static bool gpio_irq_take_pending(uint32_t line)
{
    NVIC_DisableIRQ(EXTI7_0_IRQn);
    bool pending = (gpio_irq_pending & line) != 0U;
    gpio_irq_pending &= (uint8_t) ~line;
    NVIC_EnableIRQ(EXTI7_0_IRQn);
    return pending;
}

static bool irq_pin(term pin_term, int32_t *pin, uint32_t *line, uint32_t *port)
{
    if (!term_is_integer(pin_term)) {
        return false;
    }
    *pin = term_to_int32(pin_term);
    if (!ch32v006_pin_is_safe(*pin)) {
        return false;
    }
    int32_t index = *pin & 0xF;
    int32_t port_index = *pin >> 4;
    if (index < 0 || index > 7 || port_index < 0 || port_index > 3) {
        return false;
    }
    *line = 1U << (uint32_t) index;
    *port = (uint32_t) port_index;
    return true;
}

void EXTI7_0_IRQHandler(void) INTERRUPT_DECORATOR __attribute__((used));
void EXTI7_0_IRQHandler(void)
{
    uint32_t pending = EXTI->INTFR & UINT32_C(0xFF);
    gpio_irq_pending |= (uint8_t) pending;
    EXTI->INTFR = pending;
}

static term nif_gpio_set_pin_interrupt(Context *ctx, int argc, term argv[])
{
    int32_t pin;
    uint32_t line;
    uint32_t port;
    if (argc != 2 || !irq_pin(argv[0], &pin, &line, &port)) {
        return term_invalid_term();
    }
    int edge = interop_atom_term_select_int(interrupt_edge_table, argv[1], ctx->global);
    if (edge < 0) {
        return term_invalid_term();
    }

    uint32_t index = (uint32_t) pin & 0xFU;
    RCC->APB2PCENR |= RCC_APB2Periph_AFIO;
    uint32_t exticr = AFIO->EXTICR;
    exticr &= ~(UINT32_C(3) << (index * 2U));
    exticr |= port << (index * 2U);
    AFIO->EXTICR = exticr;

    EXTI->INTENR |= line;
    EXTI->RTENR &= ~line;
    EXTI->FTENR &= ~line;
    if (edge == GPIOInterruptRising || edge == GPIOInterruptBoth) {
        EXTI->RTENR |= line;
    }
    if (edge == GPIOInterruptFalling || edge == GPIOInterruptBoth) {
        EXTI->FTENR |= line;
    }
    EXTI->INTFR = line;
    gpio_irq_clear_pending(line);
    NVIC_EnableIRQ(EXTI7_0_IRQn);
    return OK_ATOM;
}

static term nif_gpio_clear_pin_interrupt(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    int32_t pin;
    uint32_t line;
    uint32_t port;
    if (argc != 1 || !irq_pin(argv[0], &pin, &line, &port)) {
        return term_invalid_term();
    }
    UNUSED(pin);
    UNUSED(port);
    EXTI->INTENR &= ~line;
    EXTI->RTENR &= ~line;
    EXTI->FTENR &= ~line;
    EXTI->INTFR = line;
    gpio_irq_clear_pending(line);
    if ((EXTI->INTENR & UINT32_C(0xFF)) == 0U) {
        NVIC_DisableIRQ(EXTI7_0_IRQn);
    }
    return OK_ATOM;
}

static term nif_gpio_interrupt_pending(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    int32_t pin;
    uint32_t line;
    uint32_t port;
    if (argc != 1 || !irq_pin(argv[0], &pin, &line, &port)) {
        return term_invalid_term();
    }
    UNUSED(pin);
    UNUSED(port);
    return gpio_irq_take_pending(line) ? TRUE_ATOM : FALSE_ATOM;
}

DEFINE_NIF(gpio_set_pin_interrupt);
DEFINE_NIF(gpio_clear_pin_interrupt);
DEFINE_NIF(gpio_interrupt_pending);
#endif

const struct Nif *ch32v006_peripherals_get_nif(const char *nifname)
{
#ifdef AVM_CH32V006_UART
    if (strcmp("uart:init/1", nifname) == 0) {
        return &uart_init_nif;
    }
    if (strcmp("uart:write/1", nifname) == 0) {
        return &uart_write_nif;
    }
    if (strcmp("uart:read/0", nifname) == 0) {
        return &uart_read_nif;
    }
#endif
#ifdef AVM_CH32V006_ADC
    if (strcmp("adc:read/1", nifname) == 0) {
        return &adc_read_nif;
    }
#endif
#ifdef AVM_CH32V006_I2C
    if (strcmp("i2c:init/1", nifname) == 0) {
        return &i2c_init_nif;
    }
    if (strcmp("i2c:probe/1", nifname) == 0) {
        return &i2c_probe_nif;
    }
    if (strcmp("i2c:write/2", nifname) == 0) {
        return &i2c_write_nif;
    }
    if (strcmp("i2c:read/2", nifname) == 0) {
        return &i2c_read_nif;
    }
#endif
#ifdef AVM_CH32V006_SPI
    if (strcmp("spi:init/2", nifname) == 0) {
        return &spi_init_nif;
    }
    if (strcmp("spi:transfer/1", nifname) == 0) {
        return &spi_transfer_nif;
    }
    if (strcmp("spi:transfer_byte/1", nifname) == 0) {
        return &spi_transfer_byte_nif;
    }
#endif
#ifdef AVM_CH32V006_PWM
    if (strcmp("pwm:init/1", nifname) == 0) {
        return &pwm_init_nif;
    }
    if (strcmp("pwm:set_duty/2", nifname) == 0) {
        return &pwm_set_duty_nif;
    }
#endif
#ifdef AVM_CH32V006_GPIO_IRQ
    if (strcmp("gpio:set_pin_interrupt/2", nifname) == 0) {
        return &gpio_set_pin_interrupt_nif;
    }
    if (strcmp("gpio:clear_pin_interrupt/1", nifname) == 0) {
        return &gpio_clear_pin_interrupt_nif;
    }
    if (strcmp("gpio:interrupt_pending/1", nifname) == 0) {
        return &gpio_interrupt_pending_nif;
    }
#endif
    return NULL;
}
