#include <stdlib.h>

int *do_a_useful_thing()
{
	int *num = malloc(sizeof(*num));

	if (num == NULL)
	{
		return nullptr;
	}

	*num = 1;

	return num;
}
