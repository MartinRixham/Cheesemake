#include <string.h>

#include "greeting.h"

int main(void)
{
	if (strcmp(greeting(), "hello") != 0)
	{
		return 1;
	}

	return 0;
}
