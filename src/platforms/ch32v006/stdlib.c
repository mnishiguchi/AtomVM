/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/reent.h>
#include <unistd.h>

#include <ch32fun.h>

#ifndef AVM_CH32V006_STACK_RESERVE_BYTES
#define AVM_CH32V006_STACK_RESERVE_BYTES 1432U
#endif

// Reserve enough stack for nested comparisons and JIT/native call frames.
#define STACK_RESERVE_BYTES AVM_CH32V006_STACK_RESERVE_BYTES
#define STACK_GUARD_BYTES 8U
#define STACK_GUARD_WORD UINT32_C(0x51ACCA7E)
#define MALLOC_ALIGNMENT 8U
#ifdef AVM_CH32V006_SELF_TEST
#define STACK_PROBE_PATTERN 0xA5U
#endif

typedef struct HeapBlock
{
    size_t size;
    struct HeapBlock *next;
    bool free;
    uint8_t reserved[7];
} HeapBlock;

_Static_assert(sizeof(HeapBlock) % MALLOC_ALIGNMENT == 0, "HeapBlock preserves malloc alignment");

extern uint8_t _end;
extern uint8_t _eusrstack;

static HeapBlock *heap_head;
static bool stack_guard_initialized;
#ifdef AVM_CH32V006_ALLOCATOR_FAULT_INJECTION
static bool fail_next_allocation;
#endif
#ifdef AVM_CH32V006_SELF_TEST
static size_t heap_capacity;
static size_t heap_current;
static size_t heap_peak;
static uint8_t *stack_probe_start;
static uint8_t *stack_probe_end;
#endif
static int platform_errno;

static uint32_t *stack_guard(void)
{
    uintptr_t address = ((uintptr_t) &_eusrstack - STACK_RESERVE_BYTES) & ~(MALLOC_ALIGNMENT - 1U);
    return (uint32_t *) address;
}

void platform_stack_guard_init(void)
{
    uint32_t *guard = stack_guard();
    guard[0] = STACK_GUARD_WORD;
    guard[1] = ~STACK_GUARD_WORD;
    stack_guard_initialized = true;
}

bool platform_stack_guard_ok(void)
{
    uint32_t *guard = stack_guard();
    return stack_guard_initialized && guard[0] == STACK_GUARD_WORD
        && guard[1] == ~STACK_GUARD_WORD;
}

void platform_stack_guard_check(void)
{
    if (!platform_stack_guard_ok()) {
        printf("AtomVM C stack overflow\n");
        abort();
    }
}

static size_t align_size(size_t size)
{
    if (size > SIZE_MAX - (MALLOC_ALIGNMENT - 1U)) {
        return 0;
    }
    return (size + MALLOC_ALIGNMENT - 1U) & ~(MALLOC_ALIGNMENT - 1U);
}

static void coalesce_free_blocks(void)
{
    for (HeapBlock *current = heap_head; current && current->next;) {
        if (current->free && current->next->free) {
            current->size += sizeof(HeapBlock) + current->next->size;
            current->next = current->next->next;
        } else {
            current = current->next;
        }
    }
}

static void heap_init(void)
{
    platform_stack_guard_check();
    uintptr_t start = ((uintptr_t) &_end + MALLOC_ALIGNMENT - 1U) & ~(MALLOC_ALIGNMENT - 1U);
    uintptr_t limit = ((uintptr_t) &_eusrstack - STACK_RESERVE_BYTES) & ~(MALLOC_ALIGNMENT - 1U);
    if (limit <= start + sizeof(HeapBlock)) {
        return;
    }
    heap_head = (HeapBlock *) start;
    heap_head->size = limit - start - sizeof(HeapBlock);
#ifdef AVM_CH32V006_SELF_TEST
    heap_capacity = heap_head->size;
#endif
    heap_head->next = NULL;
    heap_head->free = true;
}

void *malloc(size_t size)
{
    platform_stack_guard_check();
#ifdef AVM_CH32V006_ALLOCATOR_FAULT_INJECTION
    if (fail_next_allocation) {
        fail_next_allocation = false;
        return NULL;
    }
#endif
    if (!size) {
        return NULL;
    }
    if (!heap_head) {
        heap_init();
        if (!heap_head) {
            return NULL;
        }
    }

    size = align_size(size);
    if (!size) {
        return NULL;
    }
    // Best-fit leaves larger extents intact for the contiguous allocations required by GC.
    HeapBlock *best = NULL;
    for (HeapBlock *block = heap_head; block; block = block->next) {
        if (block->free && block->size >= size && (!best || block->size < best->size)) {
            best = block;
        }
    }
    if (best) {
        if (best->size >= size + sizeof(HeapBlock) + MALLOC_ALIGNMENT) {
            HeapBlock *split = (HeapBlock *) ((uint8_t *) (best + 1) + size);
            split->size = best->size - size - sizeof(HeapBlock);
            split->next = best->next;
            split->free = true;
            best->next = split;
            best->size = size;
        }
        best->free = false;
#ifdef AVM_CH32V006_SELF_TEST
        heap_current += best->size;
        if (heap_current > heap_peak) {
            heap_peak = heap_current;
        }
#endif
        return best + 1;
    }
    return NULL;
}

#ifdef AVM_CH32V006_ALLOCATOR_FAULT_INJECTION
void platform_allocator_fail_next(void)
{
    fail_next_allocation = true;
}
#endif

void free(void *ptr)
{
    platform_stack_guard_check();
    if (!ptr) {
        return;
    }
    HeapBlock *block = (HeapBlock *) ptr - 1;
#ifdef AVM_CH32V006_SELF_TEST
    heap_current -= block->size;
#endif
    block->free = true;
    coalesce_free_blocks();
}

#ifdef AVM_CH32V006_SELF_TEST
__attribute__((noinline)) void platform_stack_probe_start(void)
{
    uintptr_t sp;
    __asm__ volatile("mv %0, sp"
                     : "=r"(sp));
    stack_probe_start = (uint8_t *) stack_guard() + STACK_GUARD_BYTES;
    stack_probe_end = (uint8_t *) sp - 64;
    for (uint8_t *cursor = stack_probe_start; cursor < stack_probe_end; ++cursor) {
        *cursor = STACK_PROBE_PATTERN;
    }
}

size_t platform_stack_peak(void)
{
    uint8_t *cursor = stack_probe_start;
    while (cursor < stack_probe_end && *cursor == STACK_PROBE_PATTERN) {
        ++cursor;
    }
    return (size_t) (&_eusrstack - cursor);
}

size_t platform_stack_reserve(void)
{
    return STACK_RESERVE_BYTES;
}

void platform_heap_stats(size_t *capacity, size_t *current, size_t *peak)
{
    *capacity = heap_capacity;
    *current = heap_current;
    *peak = heap_peak;
}
#endif

void *calloc(size_t count, size_t size)
{
    if (size && count > SIZE_MAX / size) {
        return NULL;
    }
    size_t bytes = count * size;
    void *ptr = malloc(bytes);
    if (ptr) {
        memset(ptr, 0, bytes);
    }
    return ptr;
}

void *realloc(void *ptr, size_t size)
{
    platform_stack_guard_check();
    if (!ptr) {
        return malloc(size);
    }
    if (!size) {
        free(ptr);
        return NULL;
    }

    size = align_size(size);
    if (!size) {
        return NULL;
    }
    HeapBlock *block = (HeapBlock *) ptr - 1;
    if (block->size >= size) {
        size_t old_size = block->size;
        if (old_size >= size + sizeof(HeapBlock) + MALLOC_ALIGNMENT) {
            HeapBlock *split = (HeapBlock *) ((uint8_t *) (block + 1) + size);
            split->size = old_size - size - sizeof(HeapBlock);
            split->next = block->next;
            split->free = true;
            block->next = split;
            block->size = size;
#ifdef AVM_CH32V006_SELF_TEST
            heap_current -= old_size - size;
#endif
            coalesce_free_blocks();
        }
        return ptr;
    }
    if (block->next && block->next->free
        && block->size + sizeof(HeapBlock) + block->next->size >= size) {
#ifdef AVM_CH32V006_SELF_TEST
        size_t old_size = block->size;
#endif
        block->size += sizeof(HeapBlock) + block->next->size;
        block->next = block->next->next;
        if (block->size >= size + sizeof(HeapBlock) + MALLOC_ALIGNMENT) {
            HeapBlock *split = (HeapBlock *) ((uint8_t *) (block + 1) + size);
            split->size = block->size - size - sizeof(HeapBlock);
            split->next = block->next;
            split->free = true;
            block->next = split;
            block->size = size;
        }
#ifdef AVM_CH32V006_SELF_TEST
        heap_current += block->size - old_size;
        if (heap_current > heap_peak) {
            heap_peak = heap_current;
        }
#endif
        return ptr;
    }
    void *new_ptr = malloc(size);
    if (new_ptr) {
        memcpy(new_ptr, ptr, block->size);
        free(ptr);
    }
    return new_ptr;
}

int *__errno(void)
{
    return &platform_errno;
}

struct _reent atomvm_reent;
struct _reent *_impure_ptr = &atomvm_reent;

int vfprintf(FILE *stream, const char *format, va_list args)
{
    (void) stream;
    return vprintf(format, args);
}

int fprintf(FILE *stream, const char *format, ...)
{
    (void) stream;
    va_list args;
    va_start(args, format);
    int result = vprintf(format, args);
    va_end(args);
    return result;
}

int fputc(int c, FILE *stream)
{
    (void) stream;
    return putchar(c);
}

int fputs(const char *s, FILE *stream)
{
    (void) stream;
    return _write(1, s, (int) strlen(s));
}

int fflush(FILE *stream)
{
    (void) stream;
    return 0;
}

long sysconf(int name)
{
    (void) name;
    return -1;
}

__attribute__((noreturn)) void abort(void)
{
    printf("AtomVM abort\n");
    // A peripheral (for example PWM) may have changed the result LED mode.
    funPinMode(PC3, FUN_OUTPUT);
    while (1) {
        funDigitalWrite(PC3, FUN_HIGH);
        Delay_Ms(600);
        funDigitalWrite(PC3, FUN_LOW);
        Delay_Ms(400);
    }
}

__attribute__((noreturn)) void exit(int status)
{
    (void) status;
    abort();
}
