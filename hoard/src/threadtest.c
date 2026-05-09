/*
 * threadtest.c
 *
 * Simple multi-threaded malloc/free scalability benchmark, modeled
 * after the threadtest benchmark used in the Hoard paper (Berger
 * et al., ASPLOS 2000). Each thread allocates and immediately frees
 * NITER blocks of size BSIZE, repeated NREP times. Wall-clock total
 * elapsed time is printed.
 *
 * Build:
 *   gcc -O2 -pthread -o threadtest src/threadtest.c
 *
 * Run with a specific allocator via LD_PRELOAD:
 *   LD_PRELOAD=build/libhoard.so ./threadtest <nthreads> <niter> <nrep> <bsize>
 *
 * Example (closest to paper's setup):
 *   ./threadtest 8 100000 50 64
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static int g_niter = 100000;   /* allocations per round */
static int g_nrep  = 50;       /* rounds per thread */
static int g_bsize = 64;       /* allocation size in bytes */

static void *worker(void *arg) {
    (void)arg;
    void **ptrs = (void **)malloc(sizeof(void *) * g_niter);
    if (!ptrs) { perror("malloc"); exit(1); }

    for (int r = 0; r < g_nrep; r++) {
        for (int i = 0; i < g_niter; i++) {
            ptrs[i] = malloc(g_bsize);
            /* touch first byte so allocator must commit pages */
            ((char *)ptrs[i])[0] = (char)i;
        }
        for (int i = 0; i < g_niter; i++) {
            free(ptrs[i]);
        }
    }

    free(ptrs);
    return NULL;
}

int main(int argc, char *argv[]) {
    int nthreads = (argc > 1) ? atoi(argv[1]) : 8;
    if (argc > 2) g_niter = atoi(argv[2]);
    if (argc > 3) g_nrep  = atoi(argv[3]);
    if (argc > 4) g_bsize = atoi(argv[4]);

    pthread_t *th = (pthread_t *)malloc(sizeof(pthread_t) * nthreads);
    if (!th) { perror("malloc"); return 1; }

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    for (int i = 0; i < nthreads; i++) {
        if (pthread_create(&th[i], NULL, worker, NULL) != 0) {
            perror("pthread_create");
            return 1;
        }
    }
    for (int i = 0; i < nthreads; i++) pthread_join(th[i], NULL);

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    long total_ops = (long)nthreads * g_niter * g_nrep * 2;  /* malloc + free */

    fprintf(stderr,
        "threadtest threads=%d niter=%d nrep=%d bsize=%d elapsed=%.3fs ops/s=%.0f\n",
        nthreads, g_niter, g_nrep, g_bsize, elapsed, total_ops / elapsed);

    /* one tab-separated line on stdout for easy CSV scraping */
    printf("%d\t%d\t%d\t%d\t%.6f\t%.0f\n",
        nthreads, g_niter, g_nrep, g_bsize, elapsed, total_ops / elapsed);

    free(th);
    return 0;
}