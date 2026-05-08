/*
 * sqlite_bench.c
 *
 * Reproduces the SQLite case study from the Coz paper (Curtsinger & Berger,
 * SOSP 2015). Single shared in-memory database in serialized threading mode,
 * multiple worker threads each issuing INSERT statements through that shared
 * connection. Every successful insert advances a single external progress
 * point. No COZ_PROGRESS_NAMED inside sqlite3.c.
 *
 * Why this design (vs. per-thread DBs):
 *   With SQLITE_THREADSAFE=1, all API calls on a shared connection are
 *   serialized through that connection's recursive mutex. The paper found
 *   that the cost of acquiring/releasing this mutex on every sqlite3 API
 *   call was the dominant bottleneck. To reproduce that, we have to put
 *   real traffic through that mutex. Per-thread connections (the variant
 *   used previously) bypass it.
 */

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <sqlite3.h>
#include <coz.h>

#ifndef THREAD_COUNT
#define THREAD_COUNT 8
#endif

#ifndef OPS_PER_THREAD
#define OPS_PER_THREAD 1000000
#endif

static sqlite3 *g_db = NULL;

static void die(const char *what, const char *msg) {
    fprintf(stderr, "%s: %s\n", what, msg ? msg : "(null)");
    exit(1);
}

static void *worker(void *arg) {
    long tid = (long)arg;
    sqlite3_stmt *stmt = NULL;

    if (sqlite3_prepare_v2(g_db,
            "INSERT INTO t(tid, x, y, z) VALUES (?1, ?2, ?3, ?4)",
            -1, &stmt, NULL) != SQLITE_OK) {
        die("prepare", sqlite3_errmsg(g_db));
    }

    for (int i = 0; i < OPS_PER_THREAD; i++) {
        sqlite3_bind_int(stmt, 1, (int)tid);
        sqlite3_bind_int(stmt, 2, 2 * i);
        sqlite3_bind_int(stmt, 3, 3 * i);
        sqlite3_bind_text(stmt, 4, "asdf", -1, SQLITE_STATIC);

        int rc;
        do { rc = sqlite3_step(stmt); } while (rc == SQLITE_BUSY);
        if (rc != SQLITE_DONE) die("step", sqlite3_errmsg(g_db));

        sqlite3_reset(stmt);
        sqlite3_clear_bindings(stmt);

        /* One unit of work == one committed row. */
        COZ_PROGRESS;
    }

    sqlite3_finalize(stmt);
    return NULL;
}

int main(void) {
    if (sqlite3_threadsafe() == 0) {
        fprintf(stderr,
            "FATAL: libsqlite3 was built with SQLITE_THREADSAFE=0.\n"
            "Rebuild build-custom/libsqlite3_custom.so with -DSQLITE_THREADSAFE=1.\n");
        return 1;
    }

    /* Serialized mode: all API calls on g_db serialize through its mutex. */
    if (sqlite3_config(SQLITE_CONFIG_SERIALIZED) != SQLITE_OK) {
        fprintf(stderr, "warning: sqlite3_config(SERIALIZED) failed\n");
    }

    if (sqlite3_open(":memory:", &g_db) != SQLITE_OK) {
        die("open", sqlite3_errmsg(g_db));
    }

    char *err = NULL;
    if (sqlite3_exec(g_db,
            "PRAGMA journal_mode = MEMORY;"
            "PRAGMA synchronous = OFF;"
            "PRAGMA temp_store = MEMORY;"
            "CREATE TABLE t(id INTEGER PRIMARY KEY, tid INT, x INT, y INT, z TEXT);",
            NULL, NULL, &err) != SQLITE_OK) {
        fprintf(stderr, "setup: %s\n", err);
        sqlite3_free(err);
        return 1;
    }

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    pthread_t th[THREAD_COUNT];
    for (long i = 0; i < THREAD_COUNT; i++) {
        if (pthread_create(&th[i], NULL, worker, (void *)i) != 0) {
            perror("pthread_create");
            return 1;
        }
    }
    for (int i = 0; i < THREAD_COUNT; i++) {
        pthread_join(th[i], NULL);
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    long total = (long)THREAD_COUNT * OPS_PER_THREAD;
    fprintf(stderr,
        "threads=%d ops_per_thread=%d total=%ld elapsed=%.3fs throughput=%.0f ops/s\n",
        THREAD_COUNT, OPS_PER_THREAD, total, elapsed, total / elapsed);

    sqlite3_close(g_db);
    return 0;
}