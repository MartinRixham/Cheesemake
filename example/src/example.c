#include <stdio.h>
#include <stdlib.h>

#include "subd/code.h"

int main(void)
{
	char *string = get_code();

	printf("%s%s", string, "\n");

	return 0;
}
