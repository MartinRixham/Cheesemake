#include "numbers.h"

#include <stdlib.h>

int *make_number(int value)
{
	int *number = malloc(sizeof(*number));

	if (number == NULL)
	{
		return NULL;
	}

	*number = value;

	return number;
}
