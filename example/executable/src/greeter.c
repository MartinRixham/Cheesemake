#include <stdio.h>

#include "greeting.h"

int main(int argc, char **argv)
{
	int i;

	printf("%s", greeting());

	for (i = 1; i < argc; i++)
	{
		printf(" %s", argv[i]);
	}

	printf("\n");

	return 0;
}
