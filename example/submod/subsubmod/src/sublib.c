#include "sublib.h"

#include <stdlib.h>

int *do_a_subuseful_thing()
{
	int *num = malloc(sizeof(int));

	*num = 0;

	return num;
}
