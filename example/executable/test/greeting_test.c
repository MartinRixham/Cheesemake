#include <string.h>

#include "greeting.h"

int main(int argc, char **argv)
{
	char *expected = argc > 1 ? argv[1] : "hello";

	if (strcmp(greeting(), expected) != 0)
	{
		return 1;
	}

	return 0;
}
