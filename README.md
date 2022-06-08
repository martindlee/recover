Recover is a FoxPro database recovery utility that was written by Paul Lee from 
1995 through 2005 or so, and distributed by his Abri Technologies business. It is 
being released as open source under the MIT license so that any remaining FoxPro 
users may benefit from it.

Portions of this software (specifically the "Trace" method of recovery) are 
covered by expired US patent 5,870,762 which was obtained by Paul Lee. You can 
read more at https://patents.google.com/patent/US5870762A/en

Notable directories of this file tree include:
	ADV - old advertisements for the software
	DOC - assorted documentation
	SOURCE - the main source code for the program
	VFP5 - the Visual FoxPro projects to get the main programs to build
		RECOVER.APP - the main application (royalty-free version)
		RECOVERS.APP - the main application (single-user version)
	FPD - the FoxPro for DOS projects to get the main programs to build
	FPW - the FoxPro for Windows projects to get the main programs to build

The github.com repository for the software has a 'release-4.0b' branch which 
includes Recover more or less as it was at its last release.

The 'master' branch has some changes to get the C++ utilities to compile with 
Visual Studio 2022 (instead of Borland C++). See Recover.sln in the top-level 
directory.

The software has been known to compile with Visual FoxPro 9.0 (obtainable from 
archive.org's software repository). However, we are not FoxPro programmers. We 
welcome contributors to fork this repository and maintain it as desired. In 
particular, the process of building and packaging the software could use 
streamlining. The .BAT files included to do this are not well understood.

To get Visual FoxPro 9.0 SP2 running on a recent (Windows 11) computer, you will need to:
	0. Make sure you have 7-Zip installed for step 3.

	1. Install the open source program WinCDemu from 
	https://wincdemu.sysprogs.org/ - this is needed to mount the VFP9 disc 
	image.

	2. Download and install MSXML 4.0 SP3 from
https://web.archive.org/web/20190118121218if_/https://download.microsoft.com/download/A/2/D/A2D8587D-0027-4217-9DAD-38AFDB0A177E/msxml.msi

	3. Download Visual FoxPro 9.0 from https://archive.org/details/X11-02723

		We link to this file because it appears to be a copy distributed 
		by Microsoft itself. It comes with a built-in license key.

		You will need to extract the .7z file and then use WinCDemu to 
		'open' the image/VFPPROD1.mdf file. This will attach the disc image
		and create a new virtual drive (usually V:) with its contents.

		Run V:\setup.exe

	4. Download and install VFP9_SP2.EXE and other VFP9 updates from from 
	https://github.com/VFPX/VFP9SP2Hotfix3

Again, we are not FoxPro developers.

Sincerely,
Martin Lee, mlee@rd.digital
Elliot Lee, sopwith@gmail.com
