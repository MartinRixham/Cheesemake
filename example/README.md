# Cheesemake examples

Each of these is a project that cheesemake can build, and each one is about
one thing. Run `cmk run`, or whichever phase you want, in any of them.

| Example | What it is about |
| --- | --- |
| [executable](executable) | a program, its tests, and the arguments it is run with |
| [shared-library](shared-library) | packaging sources as a shared object, and the headers that go with it |
| [static-library](static-library) | packaging sources as an archive |
| [modules](modules) | a project built from a module, which is built from a module of its own |
| [dependencies](dependencies) | packages found with pkg-config, the scopes they apply to, and defines |
| [plugins](plugins) | the plugins that come with cheesemake, and one the project provides itself |

`bottom`, the innermost module of [modules](modules), is packaged as a shared
object and an archive at once, which is what `"packaging": "shared,archive"`
is for.

The `version` plugin that [plugins](plugins) configures is asked only for a
minimum and a maximum, so that the example builds whatever version of check is
installed. It can also be given `version`, `major-version` and `minor-version`
to insist on an exact one.
