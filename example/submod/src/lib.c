#include <stdlib.h>

int *do_a_useful_thing()
{
	int *num = malloc(sizeof(int));

	*num = 1;

	return num;
}
