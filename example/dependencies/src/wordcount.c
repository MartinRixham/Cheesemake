#include <stdio.h>

#include "counter.h"

#define TEXT(value) #value
#define NAME(value) TEXT(value)

int main(void)
{
#ifdef DEBUG
	printf("built for %s\n", NAME(OS));
#endif

	printf("%u words\n", count_words("one two three"));

	return 0;
}
