# Cheesemake

Cheesemake is a declarative build tool for C/C++ written in Bash.
It comes with plugins for serveral static and dynamic validation tools such as cppcheck and valgrind as well as the ability to run custom plugins.
Read the [article](https://www.infoq.com/articles/cheesemake-c-build-system).

### Dependencies

* Bash
* jq
* pkg-config
* OpenSSL

### Install

I don't intend to provide a portable installation script but you can do something like this:

	git clone https://github.com/martinrixham/cheesemake.git
	cp -r cheesemake /opt
	ln -s /opt/cheesemake/cheesemake /usr/local/bin/cmk

### Run
	# cmk --help
	usage: cmk [clean] <phase>
	
	Cheesemake runs ALL phases in order up to the one specified.

		Phases:
		 validate		Run plugins such as static analysis tools.
		 compile		Compile sources in the src directory and output them to build/src.
		 test			Compile and run tests in the test directory.
		 package		Create a binary in build/bin or build/lib.
		 verify			Run plugins such as dynamic analysis tools.
		 run			Run build/bin/<recipe name>.

Do `cmk <phase>` in the root directory of a project containing a `recipe.json` file.

### Syntax

Please refer to the [examples](example). There is one for each thing a recipe can say: an [executable](example/executable), a [shared library](example/shared-library), a [static library](example/static-library), a project built from [modules](example/modules), [dependencies](example/dependencies) found with pkg-config, and [plugins](example/plugins), including one the project provides itself.

### Test

The [tests](test) for the script itself build the examples. Run them with `./test/run_tests.sh`.
