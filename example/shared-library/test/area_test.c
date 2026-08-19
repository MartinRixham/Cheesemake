#include "area.h"
#include "almost.h"

int main(void)
{
	if (!close_enough(area(2), 12.5663706143592))
	{
		return 1;
	}

	return 0;
}
