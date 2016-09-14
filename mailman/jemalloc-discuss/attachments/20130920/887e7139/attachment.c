#include <errno.h>
#include <stdio.h>
#include <stdlib.h>


int
main(int argc, char *argv[])
{
	(void)printf("errno=%d\n", errno);
	(void)malloc(42);
	(void)printf("errno=%d\n", errno);
	return (0);
}

/*
will output the following under FreeBSD:

errno=0
errno=2

*/
