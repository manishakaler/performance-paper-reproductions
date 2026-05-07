#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifndef NODES
#define NODES 262144
#endif

#ifndef OUTER_ITERS
#define OUTER_ITERS 96
#endif

typedef struct Node {
    uint64_t value;
    uint32_t next_a;
    uint32_t next_b;
    uint64_t salt;
} Node;

static uint64_t rng_state = 0x9e3779b97f4a7c15ULL;

static inline uint64_t xorshift64(void) {
    uint64_t x = rng_state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    rng_state = x;
    return x;
}

__attribute__((noinline))
static uint64_t mix_a(uint64_t x) {
    x ^= x >> 33;
    x *= 0xff51afd7ed558ccdULL;
    x ^= x >> 29;
    return x;
}

__attribute__((noinline))
static uint64_t mix_b(uint64_t x) {
    x ^= x << 11;
    x *= 0xc4ceb9fe1a85ec53ULL;
    x ^= x >> 31;
    return x;
}

__attribute__((noinline))
static uint64_t branch_block1(uint64_t x, uint64_t y) {
    if ((x ^ y) & 1ULL) return mix_a(x + y);
    if ((x + y) & 2ULL) return mix_b(x ^ (y >> 1));
    return (x << 7) ^ (y * 1315423911ULL);
}

__attribute__((noinline))
static uint64_t branch_block2(uint64_t x, uint64_t y) {
    if ((x - y) & 4ULL) return mix_b(x + 0x9e3779b97f4a7c15ULL) ^ y;
    if ((x + y) & 8ULL) return mix_a(y + 0xD1B54A32D192ED03ULL) + x;
    return (x * 2654435761ULL) ^ (y << 9);
}

static void shuffle(uint32_t *perm, size_t n) {
    for (size_t i = n - 1; i > 0; i--) {
        size_t j = xorshift64() % (i + 1);
        uint32_t t = perm[i];
        perm[i] = perm[j];
        perm[j] = t;
    }
}

static void init_nodes(Node *nodes, size_t n) {
    uint32_t *perm_a = malloc(n * sizeof(uint32_t));
    uint32_t *perm_b = malloc(n * sizeof(uint32_t));
    if (!perm_a || !perm_b) {
        perror("malloc");
        exit(1);
    }

    for (size_t i = 0; i < n; i++) {
        perm_a[i] = (uint32_t)i;
        perm_b[i] = (uint32_t)i;
        nodes[i].value = xorshift64();
        nodes[i].salt = xorshift64();
        nodes[i].next_a = 0;
        nodes[i].next_b = 0;
    }

    shuffle(perm_a, n);
    shuffle(perm_b, n);

    for (size_t i = 0; i + 1 < n; i++) {
        nodes[perm_a[i]].next_a = perm_a[i + 1];
        nodes[perm_b[i]].next_b = perm_b[i + 1];
    }
    nodes[perm_a[n - 1]].next_a = perm_a[0];
    nodes[perm_b[n - 1]].next_b = perm_b[0];

    free(perm_a);
    free(perm_b);
}

__attribute__((noinline))
static uint64_t walk_graph(Node *nodes, uint32_t start, size_t steps, uint64_t seed) {
    uint64_t acc = seed;
    uint32_t idx = start;

    for (size_t i = 0; i < steps; i++) {
        Node *n = &nodes[idx];

        if ((acc ^ n->value) & 1ULL) {
            acc ^= branch_block1(acc, n->salt);
            idx = n->next_a;
        } else {
            acc ^= branch_block2(acc, n->value);
            idx = n->next_b;
        }

        acc += (n->value >> (idx & 7));
        acc = (acc << 9) | (acc >> 55);
    }

    return acc ^ idx;
}

int main(int argc, char **argv) {
    size_t n = NODES;
    if (argc > 1) {
        n = strtoull(argv[1], NULL, 10);
    }

    Node *nodes = aligned_alloc(64, n * sizeof(Node));
    if (!nodes) {
        perror("aligned_alloc");
        return 1;
    }

    memset(nodes, 0, n * sizeof(Node));
    init_nodes(nodes, n);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    uint64_t acc = 0xfeedfacecafebeefULL;
    uint32_t idx = 0;

    for (int iter = 0; iter < OUTER_ITERS; iter++) {
        acc ^= walk_graph(nodes, idx, n, acc + iter);
        idx = (uint32_t)((idx + acc) % n);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed =
        (end.tv_sec - start.tv_sec) +
        (end.tv_nsec - start.tv_nsec) / 1e9;

    printf("checksum=%llu\n", (unsigned long long)acc);
    printf("elapsed_sec=%.9f\n", elapsed);

    free(nodes);
    return 0;
}