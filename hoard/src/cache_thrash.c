/*
 * cache_thrash.c
 *
 * Active false sharing benchmark from the Hoard paper.
 *
 * Each thread repeatedly mallocs a small object, writes to it many
 * times, then frees it. With a poor allocator, each thread's
 * malloc returns memory that may share a cache line with another
 * thread's recently-allocated object. The writes then trigger
 * cross-core invalidations -- "active false sharing." A good
 * allocator gives each thread chunks from per-thread heaps, on
 * separate cache lines, eliminating the contention.
 *
 * Build:
 *   gcc -O2 -pthread -o cache_thrash src/cache_thrash.c
 *
 * Run:
 *   LD_PRELOAD=build/libhoard.so ./cache_thrash <nthreads> <niter> <bsize> <writes_per_alloc>
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int    g_niter = 100000;
static size_t g_bsize = 8;
static int    g_writes = 200;

static void *worker(void *arg) {
    (void)arg;
    for (int i = 0; i < g_niter; i++) {
        volatile char *p = (volatile char *)malloc(g_bsize);
        if (!p) { perror("malloc"); exit(1); }
        for (int w = 0; w < g_writes; w++) {
            p[0] = (char)w;
            p[g_bsize - 1] = (char)(w ^ 0xFF);
        }
        free((void *)p);
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    int nthreads = (argc > 1) ? atoi(argv[1]) : 8;
    if (argc > 2) g_niter  = atoi(argv[2]);
    if (argc > 3) g_bsize  = (size_t)atoi(argv[3]);
    if (argc > 4) g_writes = atoi(argv[4]);

    pthread_t *th = (pthread_t *)malloc(sizeof(pthread_t) * nthreads);

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (long i = 0; i < nthreads; i++) {
        pthread_create(&th[i], NULL, worker, (void *)i);
    }
    for (int i = 0; i < nthreads; i++) pthread_join(th[i], NULL);

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    long total_ops = (long)nthreads * g_niter * (2L + g_writes * 2);

    fprintf(stderr,
        "cache_thrash threads=%d niter=%d bsize=%zu writes=%d elapsed=%.3fs ops/s=%.0f\n",
        nthreads, g_niter, g_bsize, g_writes, elapsed, total_ops / elapsed);

    printf("%d\t%d\t%zu\t%d\t%.6f\t%.0f\n",
        nthreads, g_niter, g_bsize, g_writes, elapsed, total_ops / elapsed);

    free(th);
    return 0;
}