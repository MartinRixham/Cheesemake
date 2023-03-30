# Cheesemake

It is not meant to be taken literally, it refers to any manufacturers of dairy products.

Cheesemake is a declarative build tool for C/C++ written in Bash. Read the [article](https://www.infoq.com/articles/cheesemake-c-build-system). 

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

Please refer to the [recipe](example/recipe.json) in the example.
