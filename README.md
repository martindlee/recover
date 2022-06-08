Recover is a FoxPro database recovery utility that was written by Paul Lee and distributed by his Abri Technologies business 
from 1995 through 2005 (give or take). It is being released as open source under the MIT license so that any remaining users 
may benefit from it.

Portions of this software (specifically the "Trace" method of recovery) are covered by expired US patent 5,870,762 which was 
obtained by Paul Lee. You can read more at https://patents.google.com/patent/US5870762A/en

Notable subdirectories of this file tree include:
	ADV - old advertisements for the software
	DOC - assorted documentation
	SOURCE - the main source code for the program
	VFP5 - the Visual FoxPro projects to get the main programs to build
		RECOVER.APP - the main application (royalty-free version)
		RECOVERS.APP - the main application (single-user version)
	FPD - the FoxPro for DOS projects to get the main programs to build
	FPW - the FoxPro for Windows projects to get the main programs to build

The github.com repository for the software has a 'release-4.0b' branch which includes Recover more or less as it was at its 
last release.

The 'master' branch has some changes to get the C++ utilities to compile with Visual Studio 2022 (instead of Borland C++). 
See Recover.sln in the top-level directory.

The software has been known to compile with Visual FoxPro 9.0 (obtainable from archive.org's software repository). However, 
we are not FoxPro programmers. We welcome contributors to fork this repository and maintain it as desired. In particular, the 
process of building and packaging the software could use streamlining. The .BAT files included to do this are not well understood.

Sincerely,
Martin Lee, mlee@rd.digital
Elliot Lee, sopwith@gmail.com
