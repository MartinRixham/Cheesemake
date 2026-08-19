#include <check.h>
#include <stdlib.h>

#include "numbers.h"

START_TEST (test_make_number)
{
	int *number = make_number(7);

	ck_assert_ptr_nonnull(number);
	ck_assert_int_eq(*number, 7);

	free(number);
}
END_TEST

Suite *numbers_suite(void)
{
	Suite *suite = suite_create("numbers");
	TCase *core = tcase_create("core");

	tcase_add_test(core, test_make_number);
	suite_add_tcase(suite, core);

	return suite;
}

int main(void)
{
	int failed;
	SRunner *runner = srunner_create(numbers_suite());

	srunner_run_all(runner, CK_NORMAL);
	failed = srunner_ntests_failed(runner);
	srunner_free(runner);

	return failed;
}
