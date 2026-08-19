#include "perimeter.h"

#include "shape/circle.h"

double perimeter(double radius)
{
	return 2 * CIRCLE_PI * radius;
}
