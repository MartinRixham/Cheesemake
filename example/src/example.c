#include <stdio.h>
#include <stdlib.h>

#include "lib.h"
#include "sublib.h"
#include "subd/code.h"

int main(void)
{
	char *string = get_code();
	int *thing = do_a_useful_thing();
	int *subthing = do_a_subuseful_thing();

	printf("%s%d%d\n", string, *thing, *subthing);

	free(thing);
	free(subthing);

	return 0;
}
