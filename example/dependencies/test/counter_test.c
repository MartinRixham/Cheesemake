#include <check.h>

#include "counter.h"

START_TEST (test_count_words)
{
	ck_assert_uint_eq(count_words("one two three"), 3);
}
END_TEST

Suite *counter_suite(void)
{
	Suite *suite = suite_create("counter");
	TCase *core = tcase_create("core");

	tcase_add_test(core, test_count_words);
	suite_add_tcase(suite, core);

	return suite;
}

int main(void)
{
	int failed;
	SRunner *runner = srunner_create(counter_suite());

	srunner_run_all(runner, CK_NORMAL);
	failed = srunner_ntests_failed(runner);
	srunner_free(runner);

	return failed;
}
