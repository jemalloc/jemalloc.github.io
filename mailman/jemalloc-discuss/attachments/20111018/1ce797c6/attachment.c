// this program verifies that the value for key == 0 is not overwritten.
// this program fails when run with jemalloc-2.2.3

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <pthread.h>

static pthread_key_t my_key;
static int my_data[1];

static void __attribute__((constructor)) my_key_init(void) {
    int r;
    my_data[0] = 0x12345678;
    r = pthread_key_create(&my_key, NULL); assert(r == 0);
    assert(my_key == 0);
    r = pthread_setspecific(my_key, my_data); assert(r == 0);
}

int main(void) {
    void *vp = malloc(1);
    int *my_data_ptr = (int *) pthread_getspecific(my_key);
    assert(my_data_ptr[0] == 0x12345678);
    free(vp);
    return 0;
}