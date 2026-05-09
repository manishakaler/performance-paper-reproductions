/*
 * cache_scratch.c
 *
 * Passive false sharing benchmark from the Hoard paper.
 *
 * Main thread allocates one small object per worker thread. Each
 * worker repeatedly writes to its own object. If the allocator
 * placed multiple workers' objects on the same cache line, every
 * write triggers cross-core cache-line invalidation traffic --
 * "passive false sharing." A good allocator (Hoard, jemalloc,
 * mimalloc) avoids this; ptmalloc2 historically does not.
 *
 * Build:
 *   gcc -O2 -pthread -o cache_scratch src/cache_scratch.c
 *
 * Run:
 *   LD_PRELOAD=build/libhoard.so ./cache_scratch <nthreads> <niter> <bsize>
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int    g_niter = 1000000;
static size_t g_bsize = 8;          /* small object -> several per cache line */
static char **g_objects;

static void *worker(void *arg) {
    long tid = (long)arg;
    char *p = g_objects[tid];
    for (int i = 0; i < g_niter; i++) {
        p[0] = (char)i;
        p[g_bsize - 1] = (char)(i ^ 0xFF);
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    int nthreads = (argc > 1) ? atoi(argv[1]) : 8;
    if (argc > 2) g_niter = atoi(argv[2]);
    if (argc > 3) g_bsize = (size_t)atoi(argv[3]);

    g_objects = (char **)malloc(sizeof(char *) * nthreads);
    if (!g_objects) { perror("malloc"); return 1; }

    /* Allocate all objects from the main thread, sequentially.
       This is what stresses passive false sharing: a non-aware
       allocator hands them out from the same arena/page. */
    for (int i = 0; i < nthreads; i++) {
        g_objects[i] = (char *)malloc(g_bsize);
        if (!g_objects[i]) { perror("malloc"); return 1; }
        g_objects[i][0] = 0;
    }

    pthread_t *th = (pthread_t *)malloc(sizeof(pthread_t) * nthreads);
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (long i = 0; i < nthreads; i++) {
        pthread_create(&th[i], NULL, worker, (void *)i);
    }
    for (int i = 0; i < nthreads; i++) pthread_join(th[i], NULL);

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    long total_writes = (long)nthreads * g_niter * 2;

    fprintf(stderr,
        "cache_scratch threads=%d niter=%d bsize=%zu elapsed=%.3fs writes/s=%.0f\n",
        nthreads, g_niter, g_bsize, elapsed, total_writes / elapsed);

    printf("%d\t%d\t%zu\t%.6f\t%.0f\n",
        nthreads, g_niter, g_bsize, elapsed, total_writes / elapsed);

    for (int i = 0; i < nthreads; i++) free(g_objects[i]);
    free(g_objects);
    free(th);
    return 0;
}