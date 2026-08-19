#include "checksum.h"

int main(void)
{
	if (checksum("abc") != 294)
	{
		return 1;
	}

	return 0;
}
