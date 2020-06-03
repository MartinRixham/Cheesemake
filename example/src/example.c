#include <stdio.h>
#include <stdlib.h>

#include "lib.h"
#include "subd/code.h"

int main(void)
{
	char *string = get_code();
	int *thing = do_a_useful_thing();

	printf("%s%d\n", string, *thing);

	free(thing);

	return 0;
}
