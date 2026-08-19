#include "checksum.h"

unsigned int checksum(const char *text)
{
	unsigned int sum = 0;

	while (*text != '\0')
	{
		sum += (unsigned char) *text++;
	}

	return sum;
}
