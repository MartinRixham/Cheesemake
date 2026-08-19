#include <stdio.h>

#include "subd/code.h"
#include "middle.h"
#include "bottom.h"

int main(void)
{
	printf("%s %d %d\n", code(), middle(), bottom());

	return 0;
}
