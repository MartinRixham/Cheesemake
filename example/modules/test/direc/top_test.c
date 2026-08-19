#include <string.h>

#include "subd/code.h"
#include "middle.h"
#include "local_head.h"
#include "direc/full_head.h"

int main(void)
{
	if (strcmp(code(), EXPECTED_CODE) != 0)
	{
		return 1;
	}

	if (middle() != EXPECTED_MIDDLE)
	{
		return 1;
	}

	return 0;
}
