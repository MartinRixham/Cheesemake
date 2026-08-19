
static int close_enough(double one, double other)
{
	return one - other < 0.000001 && other - one < 0.000001;
}
