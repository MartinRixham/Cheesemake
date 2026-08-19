#include <stdio.h>
#include <stdlib.h>

#include "numbers.h"

int main(void)
{
	int *number = make_number(7);

	if (number == NULL)
	{
		return 1;
	}

	printf("the number is %d\n", *number);

	free(number);

	return 0;
}
