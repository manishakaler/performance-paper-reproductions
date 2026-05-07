#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <pthread.h>
#include <sqlite3.h>
#include <time.h>
// #include "progress_points.h"

#ifndef THREADS
#define THREADS 2
#endif

#ifndef INSERTS_PER_THREAD
#define INSERTS_PER_THREAD 1000
#endif

#include "coz.h"

typedef struct {
    int id;
    sqlite3 *db;
} worker_arg_t;

static void die(const char *msg, int rc) {
    fprintf(stderr, "%s: %d\n", msg, rc);
    exit(1);
}

static void *worker_main(void *arg) {
    worker_arg_t *w = (worker_arg_t *)arg;
    sqlite3 *db = w->db;
    sqlite3_stmt *stmt;
    const char *sql = "INSERT INTO kv(key, value) VALUES(?, ?);";
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) die("prepare", rc);

    for (int i = 0; i < INSERTS_PER_THREAD; i++) {
        sqlite3_reset(stmt);
        sqlite3_clear_bindings(stmt);

        char key[64];
        snprintf(key, sizeof(key), "t%d_k%d", w->id, i);

        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 2, (sqlite3_int64)i);

        rc = sqlite3_step(stmt);
        if (rc != SQLITE_DONE) die("step", rc);

        COZ_PROGRESS;
    }

    sqlite3_finalize(stmt);
    return NULL;
}

int main(int argc, char **argv) {
    const char *db_path = "coz_sqlite_bench.db";
    if (argc > 1) db_path = argv[1];

    sqlite3 *db;
    if (sqlite3_open(db_path, &db) != SQLITE_OK) {
        fprintf(stderr, "open failed: %s\n", sqlite3_errmsg(db));
        return 1;
    }

    char *errmsg = NULL;
    if (sqlite3_exec(db, "PRAGMA journal_mode = WAL;", NULL, NULL, &errmsg) != SQLITE_OK) {
        fprintf(stderr, "pragma failed: %s\n", errmsg);
        sqlite3_free(errmsg);
    }

    if (sqlite3_exec(db, "DROP TABLE IF EXISTS kv;", NULL, NULL, &errmsg) != SQLITE_OK) {
        fprintf(stderr, "drop failed: %s\n", errmsg);
        sqlite3_free(errmsg);
        return 1;
    }

    if (sqlite3_exec(db, "CREATE TABLE kv(key TEXT PRIMARY KEY, value INTEGER);",
                     NULL, NULL, &errmsg) != SQLITE_OK) {
        fprintf(stderr, "create failed: %s\n", errmsg);
        sqlite3_free(errmsg);
        return 1;
    }

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    pthread_t threads[THREADS];
    worker_arg_t args[THREADS];

    for (int i = 0; i < THREADS; i++) {
        args[i].id = i;
        args[i].db = db;
        if (pthread_create(&threads[i], NULL, worker_main, &args[i]) != 0) {
            perror("pthread_create");
            return 1;
        }
    }

    for (int i = 0; i < THREADS; i++) {
        pthread_join(threads[i], NULL);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed =
        (end.tv_sec - start.tv_sec) +
        (end.tv_nsec - start.tv_nsec) / 1e9;
    printf("elapsed_sec=%.6f\n", elapsed);

    sqlite3_close(db);
    return 0;
}