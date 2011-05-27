#!/bin/bash
# This script backs up the directory specified in the command arguments
#######################
# By: Robert McGinley
#######################
# Changelog:
# v1.0 - Initial release 6/3/2010
# v1.1 - Updated to use p7zip instead of tar+bzip2 - 5/26/2011
# v1.2 - Added some error checking and cleanup routines
# v1.3 - Added /bin/time tracking for the archival process
# v1.3.1 - Bugfix...
# v1.3.2 - Added "quiet" option for crontabs. Should still keep the output on so cron will email you the results
# v1.3.3 - Removed "quiet" code due to some errors (that I wasn't willing to fix yet)
# v1.4 - Added 7z specific error checking
# v1.4.1 - Added option to create $DESTDIR if it doesn't exist and $CREATEDIRS option variable to switch it on/off
# v1.5 - Added tons of error checking routines

###########
# Options #
###########
# TODO: Set these options up as optional switches and evaulate using switch/case

# Set the destination path where the finalized archive should go
DESTPATH="~/files/backup"	#	"~/" is default

# Sets the script to limit output (Not yet implemented)
QUIET="0"	#	Either 0 = false (Default); 1 = true

# If there's an error, cleanup any remaining files (You should keep this set to 1 unless you're troubleshooting)
CLEANUPONERROR="1"	#	Either 0 = false; 1 = true (Defualt)

# Create needed directories if the do not already exist
CREATEDIRS="1"	#	Either 0 = false; 1 = true (Default)

#############
# Functions #
#############

function printUsage () {
	echo -e "Purpose: Backs up the specified directory.\nUsage: $0 <directory> [overwrite existing archives (0|1)]"
    echo -e "\t<directory>\tRequired\n\tDirectory to backup\n"
    echo -e "\t[overwrite existing archives (0|1)]\tOptional\n\tIf an existing backup file exists,\n\t\tselect 0 to not overwrite existing file (Script will terminate)\n\t\tselect 1 to overwrite existing file"
}

function cleanupOnError () {
	if [ "$CLEANUPONERROR" -eq 1 ]; then
		# Delete the remaining archive file we created
		if [ -f "$DESTPATH/$ARCHIVENAME" ]; then
			echo -n "[*] Removing incomplete archive files... "
			/bin/rm -f $DESTPATH/$ARCHIVENAME
			if [ "$?" -eq 0 ]; then
				echo "Complete"
				sleep 3
			else
				echo "FAILED"
				sleep 3
				return 1
			fi
		fi

		# Clean up the temporary file that we create using /bin/time
		if [ -f ~/.temptime ]; then
			
			/bin/rm -f ~/.temptime
			if [ "$?" -eq 0 ]; then
				echo "Complete"
				sleep 3
			else
				echo "FAILED"
				sleep 3
				return 1
			fi
		fi	
	fi
}

########
# Code #
########

#############################
# Pre-Flight Error Checking #
#############################

# User input and general pre-flight error checking
if [ -z "$1" ]; then
	printUsage
	exit 1
else
	FILEEXT="7z"
	DATETIME=`/bin/date --rfc-2822 | tr -d "," | tr -t " " _`
	DIRECTORY="$1"
	ARCHIVENAME="$DIRECTORY_Backup_$DATETIME.$FILEEXT"

	if [ -z "$DESTPATH" || "$DESTPATH" = "" ]; then
		#Set default destination for the archive since its not already set
		echo "[*] Setting default backup destination"
		DESTPATH="~/files/backup"
	fi

	# Check if $DESTPATH exists
	if [ ! -f "$DESTPATH" ]; then
		echo "[!] Warning: Specified destination directory $DESTPATH does not exist"
		if [ "$CREATEDIRS" -eq 1 ]; then
			echo "[*] Creating directory $DESTPATH"
			/bin/mkdir -p "$DESTPATH"
			if [ "$?" -ge 1 ]; then
				echo -e "[!!] Error: Unable to create directory $DESTPATH. Check the permissions of this directory and it's parent, and check the value of \$DESTDIR in the beginning of the script.\nQuitting."
				exit 2
			fi
		elseif [ ! -d "$DESTPATH" ]; then
			echo -e "[!!] Error: Specified destination directory $DESTPATH exists but is not a directory. Please check the value of \$DESTDIR in the beginning of the script.\nQuitting."
			exit 3
		elseif [ ! -r "$DESTPATH" ]; then
			echo -e "[!!] Error: Specified destination directory $DESTPATH exists but is not readable. Please check the permissions of $DESTDIR and ensure you have permission to read this directory, or check the value of \$DESTDIR in the beginning of the script.\nQuitting."
			exit 4
		elseif [ ! -w "$DESTPATH" ]; then
			echo -e "[!!] Error: Specified destination directory $DESTPATH exists but is not writable. Please check the permissions of $DESTDIR and ensure you have permission to write to this directory, or check the value of \$DESTDIR in the beginning of the script.\nQuitting."
			exit 5
		fi
	fi	
fi

# Why does this always create an error?
#7ZOPT="-bd -ssw -mx9 -mhc=on -mf=on -m0=LZMA2 -md=64m -mmf=bt4 -mmc=10000 -mfb=273 -mlc=4 -mmt -ms=on -mtc=on -slp -scsUTF-8 -sccUTF-8"

###############
# Backup Code #
###############

if [ -d "$DIRECTORY" && -r "$DIRECTORY" ]; then		# TODO: Don't need this check here as it's performed above
	echo "Backing up $DIRECTORY..."
	#/bin/tar cjf ~/files/$2/backup/$DIRECTORY_backup_`date -I`.tar.bz2 ~/$DIRECTORY
	/usr/bin/time -p -q -o ~/.temptime ~/bin/7z a -t7z -bd -ssw -mx9 -mhc=on -mf=on -m0=LZMA2 -md=64m -mmf=bt4 -mmc=10000 -mfb=273 -mlc=4 -mmt -ms=on -mtc=on -slp -scsUTF-8 -sccUTF-8 $DESTPATH/$ARCHIVENAME $DIRECTORY/
	RET="$?"
	TIMETAKEN=`cat ~/.temptime`; /bin/rm -f -- ~/.temptime	

	if [ $QUIET != "1" ]; then
		case "$RET" in
			0)
				echo "[*] Directory archival completed successfully. Your backup is located at $DESTPATH/$ARCHIVENAME."
				if [ "TIMETAKEN" ]; then
					echo "[*] Compession time taken: $TIMETAKEN`
				fi
				exit 0
			;;
			1)
				echo "[!] Warning: There was a warning (non-fatal error) while archiving $DESTPATH"
				echo "[*] Directory archival completed successfully. Your backup is located at $DESTPATH/$ARCHIVENAME."
				if [ "TIMETAKEN" ]; then
					echo "[*] Archival time taken: $TIMETAKEN"
				fi
				exit 0
			;;
			2)
				echo "[!!] Error:There was an unspecified fatal error while archiving $DESTPATH"
				echo "[!!] Directory archival did not complete successfully."
				cleanupOnError
				echo "[*] Quitting"
					exit 2
			;;
			7)
				echo "[!!] Error: There was an error with the command line for 7z."
				echo "[!!] Please review the script contents or contact the author."
				cleanupOnError
				echo "[*] Quitting"
				exit 7
			;;
			8)
				echo "[!!] Error: There is not enough memory to complete the requested operation with the settings supplied."
				echo "[!!] Please review the script contents and adjust the dictionary size switch (-md=) provided to 7z or contact the author."
				cleanupOnError
				echo "[*] Quitting"
				exit 8
			;;
			255)
				echo "[!!] Error: Compression was terminated by user command."
				cleanupOnError
				echo "[*] Quitting"
				exit 255
			;;
			*)
				echo "[!] Warning: An unspecified error has occured. Since it is unspecified, the generated archive has not been automatically removed. Please verify that the archive is complete
			esac
	fi		
#	if [ "$?" -ne 0 ]; then
#		echo "An error occured while archiving $DIRECTORY.\nCheck 7z output above for more information"
#		exit 1
#	fi

	exit 0
else
	echo -e "Specified directory is either not a directory or not readable.\n Check your input and/or the permissions of the directory you wish to back up.\nExiting."
	exit 1
fi
