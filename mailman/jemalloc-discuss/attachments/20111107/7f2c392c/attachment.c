#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <pthread.h>

void *tester(void *arg) {
    void *ptr = NULL;
    size_t s = 4<<20;
    while (1) {
        ptr = realloc(ptr, s);
        assert(ptr);
        s *= 2;
        if (s > 256<<20)
            s = 4<<20;
    }
    return arg;
}

int main(int argc, char *argv[]) {
    int nthreads = 8;
    pthread_t pids[nthreads];
    for (int i = 1; i < nthreads; i++) {
        pthread_create(&pids[i-1], NULL, tester, NULL);
    }
    tester(NULL);
    for (int i = 1; i < nthreads; i++) {
        void *ret;
        pthread_join(pids[i-1], &ret);
    }
    return 0;
}