#include <stdio.h>
#include "code.h"

int main(int argc, char *argv[])
{
	char *string = get_code();

	printf("%s%s", string, "\n");
}
