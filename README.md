# Cheesemake

It is not meant to be taken literally, it refers to any manufacturers of dairy products.

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

Do `cmk <phase>` in the root directory of a project containing a `recipe.json` file. `cmk --help` will give details of the available phases.
