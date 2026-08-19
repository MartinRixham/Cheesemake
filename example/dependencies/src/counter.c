#include "counter.h"

guint count_words(const gchar *text)
{
	gchar **words = g_strsplit(text, " ", -1);
	guint count = g_strv_length(words);

	g_strfreev(words);

	return count;
}
