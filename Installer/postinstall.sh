#!/bin/bash
# This is a package post-install script for GPGServices.


# config #######################################################################
package="gpgpreferences"
sysdir="/Library/PreferencePanes"
homedir="$HOME/Library/PreferencePanes"
bundle="GPGPreferences.prefPane"
USER=${USER:-$(id -un)} 
temporarydir="$2"
################################################################################


# Find real target #############################################################
existingInstallationAt=""

if [[ -e "$homedir/$bundle" ]]; then
	existingInstallationAt="$homedir"
	target="$homedir"
elif [[ -e "$sysdir/$bundle" ]]; then
	existingInstallationAt="$sysdir"
	target="$sysdir"
else
	target="$sysdir"
fi

################################################################################

echo "Temporary dir: $temporarydir"
echo "existing installation at: $existingInstallationAt"
echo "installation target: $target"

# Check if GPGPreferences is correct installed in the temporary directory.
if [[ ! -e "$temporarydir/$bundle" ]] ;then
	echo "[$pacakge] Couldn't install '$bundle' in temporary directory $temporarydir.  Aborting." >&2
	exit 1
fi
################################################################################

# Cleanup ######################################################################
if [[ "$existingInstallationAt" != "" ]]; then
	echo "[$package] Removing existing installation of the bundle..."
	rm -rf "$existingInstallationAt/$bundle" || exit 1
fi
rm -rf "$sysdir/GPGTools.prefPane" "$HOME$sysdir/GPGTools.prefPane" "$sysdir/GnuPG.prefPane" "$HOME$sysdir/GnuPG.prefPane"
################################################################################

# Proper installation ##########################################################
echo "[$package] Moving bundle to final destination: $target"
if [[ ! -d "$target" ]]; then
	mkdir -p "$target" || exit 1
fi
mv "$temporarydir/$bundle" "$target/" || exit 1
################################################################################


# Permissions ##################################################################
echo "[$package] Fixing permissions..."
if [ "$target" == "$homedir" ]; then
    chown -R "$USER:staff" "$homedir/$bundle"
fi
chmod 755 "$target"
chmod -R u=rwX,go=rX "$target/$bundle"
################################################################################

exit 0
