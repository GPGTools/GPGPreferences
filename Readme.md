GPGPreferences
==============

GPGPreferences is used to set GPG releated preferences on your Mac.

Updates
-------

The latest releases of GPGPreferences can be found on our [official website](https://gpgtools.org/gpgpreferences/).

For the latest news and updates check our [Twitter](https://twitter.com/gpgtools).

Visit our [support page](https://gpgtools.tenderapp.com) if you have questions or need help setting up your system and using GPGPreferences.

Prerequisites
-------------
In order to use GPGPreferences you need to have GnuPG installed. You can either build your own version, use one from [homebrew](http://brew.sh) or find a packaged version for OS X at [gpgtools.org](https://gpgtools.org)

Build
-----

#### Clone the repository
```bash
git clone https://github.com/GPGTools/GPGPreferences.git
cd GPGPreferences
```

#### Grab Dependencies
In order to communicate with GnuPG we use our own Objective-C framework called Libmacgpg. It's necessary to clone the Libmacgpg repository first, before building GPGPreferences.

```bash
cd Dependencies
git clone --recursive https://github.com/GPGTools/Libmacgpg.git
cd ..
```

#### Build
```bash
make
```

#### Install
Copy Libmacgpg.framework from Dependencies/Libmacgpg/build/Release/ to ~/Library/Frameworks.

After that copy the GPGPreferences.prefPane file from build/Release/GPGPreferences.prefPane to ~/Library/PreferencePanes/, re-start System Preferences and enjoy.

System Requirements
-------------------

* Mac OS X >= 10.6
* Libmacgpg
* GnuPG
