homebrew-rmtree
===============

Remove a formula and its unused dependencies

## What is it?

It's an [external command][ec] for [Homebrew][h] that provides a new command, `rmtree`,
that will uninstall that formula, and uninstall any of its dependencies
that have no formula left installed that depend on them. The command will check all dependencies
recursively starting at the one specified on the command line.

This is tricky business. So this command comes with a warning.

[ec]: https://github.com/mxcl/homebrew/wiki/External-Commands
[h]: https://github.com/mxcl/homebrew

### Warning

There are formulae that do not specify all of their dependencies. This means that it is possible that
this command will remove something you still need or won't remove something you no longer want. Generally, it is pretty good.
Until someone comes up with a clever way around this, you need to be careful what you uninstall.
A formula could also depend on something you want to keep around, while nothing else actually
depends on it (except you). See Usage to ignore certain formula from being removed.

## Installation

Tap this repository and install via `brew` itself.

```
$ brew tap beeftornado/rmtree
```

Once you've tapped it, you can use the command as described above.

## Usage

Although the script's name is `brew-rmtree.rb`, [Homebrew external
commands][ec] work in such a way that you invoke it as `brew rmtree`. (It
functions exactly like a sub-command built into Homebrew.)

### Examples

Typical use case, will remove `mpv`

```
$ brew rmtree mpv
==> Examining installed formulae required by mpv...
 -  43 / 43

Can safely be removed
----------------------
automake
lua
mpg123
mpv-player/mpv/libass-ct

Proceed?[y/N]: y
==> Cleaning up packages safe to remove

Uninstalling /usr/local/Cellar/mpv/0.9.2... (342 files, 35M)

Uninstalling /usr/local/Cellar/automake/1.15... (130 files, 3.2M)

Uninstalling /usr/local/Cellar/libass-ct/HEAD... (9 files, 440K)

Uninstalling /usr/local/Cellar/lua/5.2.4... (81 files, 1.1M)

Uninstalling /usr/local/Cellar/mpg123/1.22.2... (16 files, 656K)
```
    
Trying to remove something required by something else

```
$ brew rmtree python
python can't be removed because other formula depend on it:
mpv-player/mpv/mpv, newt, node, postgresql, sip, yasm
$ brew rmtree --force python
... (I'm not going to run this but it would remove python)
```

Want to see what will happen without making any changes?

```
$ brew rmtree --dry-run mpv
This is a dry-run, nothing will be deleted
Examining installed formulae required by mpv...43 / 43 

Can safely be removed
----------------------
automake
lua
mpg123
mpv-player/mpv/libass-ct

Won't be removed
-----------------
autoconf is used by pyenv, homebrew/dupes/rsync
cairo is used by pango
cmake is used by eigen, mysql, homebrew/science/opencv, zbackup
faac is used by ffmpeg
ffmpeg is used by homebrew/science/opencv
fontconfig is used by imagemagick, pango
freetype is used by graphviz, imagemagick
fribidi is used by libass
gettext is used by newt
git is used by homebrew/headonly/arcanist, caskroom/cask/brew-cask, beeftornado/rmtree/brew-rmtree, go, gobject-introspection, mongodb, x264
glib is used by atk, gdk-pixbuf, pango
gobject-introspection is used by atk, gdk-pixbuf, gtk+, pango
harfbuzz is used by pango
icu4c is used by node, sqlite
jpeg is used by gdk-pixbuf, imagemagick, jasper, homebrew/science/opencv, wxmac
lame is used by ffmpeg
libass is used by ffmpeg
libffi is used by glib
libgpg-error is used by libksba
libogg is used by libvorbis
libpng is used by gdk-pixbuf, graphviz, imagemagick, homebrew/science/opencv, pngquant, s-lang, wxmac
libtiff is used by gdk-pixbuf, imagemagick, homebrew/science/opencv, wxmac
libtool is used by imagemagick
libvo-aacenc is used by ffmpeg
libvorbis is used by ffmpeg
libvpx is used by ffmpeg
little-cms2 is used by imagemagick
openssl is used by freetds, libevent, mongodb, mysql, node, postgresql, wget, zbackup
pixman is used by cairo
pkg-config is used by atk, cloog, homebrew/versions/cloog018, freetds, gdk-pixbuf, graphviz, gtk+, imagemagick, libevent, node, homebrew/science/opencv, openexr, pango, pngquant, pyenv, tmux
python is used by newt, node, postgresql, sip, yasm
texi2html is used by ffmpeg
webp is used by imagemagick
x264 is used by ffmpeg
x265 is used by ffmpeg
xvid is used by ffmpeg
xz is used by atk, coreutils, gdk-pixbuf, gtk+, hicolor-icon-theme, imagemagick, isl, mpfr, nasm, pango, watch, wget, zbackup
yasm is used by ffmpeg
```

## Options

Option | Description
-------|------------
`--force` | Overrides the dependency check for just the top-level formula you are trying to remove. If you try to remove 'ruby' for example, you most likely will not be able to do this because other fomulae specify this as a dependency. This option will let you remove 'ruby'. This will NOT bypass dependency checks for the formula's children. If 'ruby' depends on 'git', then 'git' will still not be removed.
`--ignore` | Ignore some dependencies from removal. This option must appear after the formulae to remove.
`--dry-run` | Does a dry-run. Goes through the whole process without actually removing anything. This gives you a chance to observe what packages would be removed and a chance to ignore them when you do it for real.
`--quiet` | No output

