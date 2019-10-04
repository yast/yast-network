# Integration tests of the Command Line Interface (CLI)

The idea is to have in each YaST package a standardized way to run
integration tests of the CLI features.

Then we should be able to write an adapter for openQA or whatever CI
system to run such tests.

## Running

> **Warning**, they will reconfigure your system (actually the current ones
  try to clean up after themselves, but they are not guaranteed to stay this
  way), so use them in a scratch VM.

```sh
# run in top level directory as prove searching for 't' directory
prove --verbose
```

`prove` is a runner for the [Test Anything Protocol](http://testanything.org/),
which has a stdio interface and thus is well suited for command line tests.
The program is conveniently part of a base openSUSE system, in perl5.rpm.
