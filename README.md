homebrew-rmtree
===============

Remove a formula and its unused dependencies

## What is it?

It's an [external command][ec] for [Homebrew][h] that provides a new command, `rmtree`,
that will uninstall that formula, examine its dependencies and uninstall them as well
if there are no remaining formula that depend on them. The command will check all dependencies
recursively starting at the one specified on the command line.

This is tricky business. The command as it stands right now is pretty straight-forward.
So this command comes with a warning.

[ec]: https://github.com/mxcl/homebrew/wiki/External-Commands
[h]: https://github.com/mxcl/homebrew

### Warning

There are formulas that do not specify all of their dependencies. This means that it is possible that
this command will remove something you still need. Until someone comes up with a clever way around this,
you need to be careful what you uninstall.

## Usage

Although the script's name is `brew-rmtree.rb`, [Homebrew external
commands][ec] work in such a way that you invoke it as `brew rmtree`. (It
functions exactly like a sub-command built into Homebrew.)

    $ brew rmtree libmpc08
    Uninstalling /usr/local/Cellar/libmpc08/0.8.1...
    Found lingering dependencies
    mpfr2
    Removing dependency mpfr2...
    Uninstalling /usr/local/Cellar/mpfr2/2.4.2...
    Found lingering dependencies
    gmp4
    Removing dependency gmp4...
    Uninstalling /usr/local/Cellar/gmp4/4.3.2...

## Installation

You can install `brew rmtree` in two ways.

1. Tap this repository and install via `brew` itself.

    ```
    $ brew tap beeftornado/rmtree && brew install beeftornado/rmtree/brew-rmtree
    ```

1. Install manually.

    ```
    $ git clone https://github.com/beeftornado/homebrew-rmtree.git && cd homebrew-rmtree
    $ mv brew-rmtree.rb /usr/local/bin/ && chmod 0755 /usr/local/bin/brew-rmtree.rb
    ```

Once you've installed via either method, you can use the command as
described above.
