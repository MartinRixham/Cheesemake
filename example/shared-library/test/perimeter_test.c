#include "perimeter.h"
#include "almost.h"

int main(void)
{
	if (!close_enough(perimeter(2), 12.5663706143592))
	{
		return 1;
	}

	return 0;
}
