Free Pascal Installer (Eleazar fork)

First version:  https://bitbucket.org/reiniero/fpcup<br/>
Second version: https://github.com/LongDirtyAnimAlf/Reiniero-fpcup<br/>
Third version:  https://github.com/newpascal/fpcupdeluxe<br/>


[![License](https://img.shields.io/badge/license-zlib%2Flibpng-blue.svg)](LICENSE)

fpc-ele-install
===============

fpc-ele-install is a fork of Fpcup, fpclazup and fpcupdeluxe, which are all 
basically wrappers around version control and build control tooling for 
installing and building any version of FreePascal and lazarus you want.

The Fcpupdeluxe version added a GUI to ease its use.  This one strips 99%
of the choices out of that for initial installs, and just gets you running.

Shortcut on your desktop are created that point to the new (Lazarus) installation.

Meant to be used side by side with other FPC/Lazarus installations. It creates a
separate primary config path directory for the new Lazarus installation, so it
doesn't interfere with existing Lazarus installs.

It's open source software released under the LGPL with linking exception
(same as FreePascal), and contains some open source libraries with their own license.
See source files for details.
All use permitted, also commercial, but no warranties, express or implied.

Using the program (binary)
==========================

Windows
------------
  - Just download a binary (.exe) of fpc-ele-install and run.

  - If needed, the tool will download all needed binaries (bootstrap compiler, binutils, svn executable)

Linux
------------

  - Just download a shell script and run it.

  - Or you can manually install
    - GNU make
    - the binutils (make etc); e.g. in a package called build-essential
    - GIT client
    - bunzip2 (probably present in most distributions)
    - unzip
    - untar
    - gdb 
    - libX11, libgdk_pixbuf-2.0, libpango-1.0, libgdk-x11-2.0

on Debian or Ubuntu, do something like:

```
sudo apt install make binutils build-essential gdb subversion zip unzip libx11-dev libgtk2.0-dev libgdk-pixbuf2.0-dev libcairo2-dev libpango1.0-dev
```

Apple OSX
------------

- Download a binary and run it. 

- Xcode and Xcode command line tools

In case of this error: "fpcupdeluxe-aarch64-darwin-cocoa.app” is damaged and can’t be opened" :
```
xattr -cr fpcupdeluxe-aarch64-darwin-cocoa.app
```
The "xattr -cr fpcupdeluxe-aarch64-darwin-cocoa.app" is [still] needed due to the fact that fpcupdeluxe is an external binary not originating from the app-store.


Cross compiler extensions
=========================
Fpcupdeluxe has a facility to extend its functionality building and using cross compiling modules.


Contact
=======
Warren Postma <warren.postma@gmail.com
