Royalty free package for non FoxPro applications - 32 bit for Windows
=====================================================================
(RecovPkg5.zip)

This uses the older Visual Foxpro 5 library files and is sufficient
for repairing all Foxpro files up to Version 7 of Visual Foxpro.
Its advantage is that it only requires two FoxPro DLL files
totaling about 4MB. Whereas for the VFP8+ requirements there are
5 required DLL files totaling about 17MB.

If you require repair of Visual Foxpro 8+ AutoIncrement files please
download the RecovPkg8.zip - see selection table at
http://www.abri.com/recover.html#FpRun for proper choices.

Recover is written in FoxPro, but this package enables you to launch
Recover main files RECOVER.APP and GENDEF.APP, from non-FoxPro
applications by calling the RecovPkg.exe and Gendefs.exe respectively
from your program or from windows (batch processing). 

Recover error scanning / repair is accomplished through the dBaseIII
table RECOVLST.DBF (shared mode) in which you indicate the tables you
want repaired, Recover options you want to use, and whether the table
is to be done in a particular run. RecovPkg.exe scans the table and
launches Recover with corresponding parameters for each entry.

Gendefs.exe is used to launch Gendef.app to 
generate the appropriate .DEF files as outlined below.

Please read MANUAL.TXT file to learn how Recover works. Since you are
not running Recover from FoxPro it is not intended that you use FoxPro
sample code and programming method suggestions in the MANUAL.TXT file.
Instead you use the method outlined below.

The list of required files related to this package are:

FileName          Purpose
-------------------------
RECOVPKG.EXE    - launches RECOVER.APP to ErrorScan/Repair
RECOVER.APP     - required by RECOVPKG.EXE
RECOVLST.DBF    - Recover/Gendef action table
GENDEFS.EXE     - launches GENDEF.APP for generating .DEF files
GENDEF.APP      - requred for GENDEFS.EXE
        Note: GENDEFS.EXE/GENDEF.APP do not have to be distributed to
        clients once the .DEF files are generated.
BROWSE.EXE      - a handy RECOVLST.DBF browsing utility
                  if you don't have one of your own.
                  (Not required for client distribution)
VFP500.DLL & VFP5ENU.DLL - required FoxPro DLL files.

The RunRec5.zip part of the package includes the additional file
RunRec5.exe and ReadmeSU.txt which are intended for single user
standalone package applications and can be deleted.

1) Filling in the RECOVLST.DBF table:
=====================================

With your database tool fill in the dBaseIII table RECOVLST.DBF with the list of files to
test/repair with your database tool. An example record is:

TablePath         MemoFile         RecovOpts   RecResult  DoThisOne Finished GendefOpts GendefRes  DoGenDef
C:\SAMPLE1.DBF    C:\SAMPLE1.FPT   TTTTTTFFFT    0           T          F    FFFTFF       0          T
...etc... more records as needed.....

The field list and explanations are:

Field Name  Type      Width                 Purpose
=======================================================================
TABLEPATH   Character 60     Full pathname of record file
      (You can omit the table directory part if the file is in current directory.)
MEMOFILE    Character 60     Full pathname of memo file (leave blank if .FPT or .DBT)
RECOPTS     Character 25     Recover option codes - see manual.txt file section 3.1
RECRESULT   Numeric    3     Recover return values - see section 3.2
DOTHISONE   Logical    1     Replace this with T if you want this table tested/repaired
FINISHED    Logical    1     Place F here initially, Recover will replace this with T
DATEDONE    Date       8     Recover will place the current date if DOTHISONE is T
TIMEDONE    Character 10     Recover will place the current time if DOTHISONE is T
GENDEFOPTS  Character  6     Gendef option codes - see section 3.5
GENDEFRES   Numeric    3     Gendef return values - see section 3.4
DOGENDEF    Logical    1     Place T if you want .def file made for this file - else F (false)

Note: Gendef will generate def files only for the records having DOTHISONE = T (true)

Note 2: You can leave RECOPTS and GENDEFOPTS empty for standard options. This is usefull
to get started.

2) Generating the def. files
============================

Please see sections 2.3 and 3.3. (manual.txt file)

Except for trivial header record and memo counter repairs, RECOVER
requires a definition file 'filename.def' to be present in the same
directory. The definition file is generated with the GenDef.app
utility which is called with the GenDefs.exe file.

Gendefs.exe uses the last three fields in the RECOVLST.DBF table.

Note: Do not rename Gendefs.exe to Gendef.exe since Gendef is also
a FoxPro application file used in the def generation process.

Note 2: If you prefer you can download the VFP5 demo package
standalone and use the interface there to generate the .DEF files.
The demo does not repair non demo files but it does generate .def
files for any table and it is easier to use on single files.

Note 3: GENDEF.APP and RECOVLST.DBF must be in same directory
where GENDEFS.EXE is executed, since GENDEFS.EXE launches
GENDEF.APP which in turn requires RECOVLST.DBF.

3) Running Recover to test or repair tables.
============================================

After you fill in the RECOVLST.DBF table you can start the Recover
operation by simply calling the RecovPkg.txt from windows.

You can even launch RecovPkg.exe from your own windows application and
then have your application occasionally check the RECOVLST.DBF file
last Finished field for which you had DoThisOne = T. If you do that it
might be a good idea to put some sort of sleep timer in between checks
in your application or some way to wait till RecovPkg.txt is done, so
that your application does not waste a lot of CPU time and slow down
the Recover operation. This is particularly important if you have very
large tables which require a lot of time to scan and repair.

Note: Do not rename RecovPkg.exe to Recover.exe since Recover is also
a FoxPro application file used in the repair process.

Note 2: RECOVER.APP and RECOVLST.DBF must be in same directory
where RecovPkg.EXE is executed, since RecovPkg.EXE launches
RECOVER.APP which in turn requires RECOVLST.DBF.

4) Handy Browse.exe utility
===========================
If you wish to make a quick manual change to the RECOVLST.DBF table
just bring this up and you can browse the table, make changes to
records, append records, mark record for deletion and remove deleted
records (PACK).
The Browse title has the necessary command prompts. Or you can
use the Table menu.

5) Recover Trace Method.
========================

Please read the general information in MANUAL.TXT regarding the Trace
method. Note that current Recover edition works only with Trace method
in FoxPro tables.

If you have sensitive data - for example, banking or legal system data
- the trace method can add an additional measure of reliable data
recovery. The method however, requires additional changes to your
program code, an additonal 7 or 16 character wide "R_TRACE_" field at
beginning of the data table and 19 character special code at beginning
of each text memo if you are using memos. In the case of memos, your
program must select the memo contents past the first 19 characters so
that your end-user is not distracted by it. In addition, the data
tables must be in healthy condition before you implement the trace
method.

MANUAL.TXT file describes FoxPro code to implement the trace method.
You can attempt to convert the FoxPro related functions ("procedures")
RTRACE.PRG, MEMOGET.PRG and MEMOPUT.PRG to your compiler syntax.
But a summary of requirements is given below. You should always test
your changes thoroughly before using Trace method in "live" data.
You don't need to convert every table to the trace method - only very
active and important tables that are crucial. Others that can be
easily restored from backup or "static" tables are probably best left
as is.

Use the Gendefs utility to convert your tables to the trace method by
placing the correct option codes in RECOVLST.DBF "GENOPTS" field.

R_TRACE_ Field:
---------------

This field is 7 bytes wide for tables without memo data protection
option or 16 bytes wide if memo protection is also desired.

Your application must maintain the R_TRACE_ field contents whenever
a new record is added.

1) Tables Without Memos or without Trace Memo protection option.

The R_TRACE_ field is 7 bytes wide and has the the seven "ReCoVeR"
characters in every record. You application must add those characters
to the R_TRACE_ field whenever a record is added and it must not
change. In case of severe damage by the operating system or compiler,
Recover utility can look for all remaining records by simply searching
for the "ReCoVeR" string and then restore the structure of the file.

IMPORTANT: Please view enclosed SAMPLE1.DBF table to see how the
R_TRACE_ code is implemented for tables without memos.


2) Tables with memos and tables with Trace memo protection option.

The R_TRACE_ field is 16 characters wide. The first 7 characters are
same as above ("ReCoVeR"). The next 9 characters are unique,
non-repeating 9 byte sequence. If you decide to maintain it with 9
numeric non-repeating characters, remember that 9 characters will
limit your table to about 1 billion records ('000000000' to
'999999999'). A random 9 character sequence generation is also
possible as used in FoxPro code examples provided with the Recover
package. But make sure that your random character string generator
will NOT repeat any code in the same table.

You cannot use the Record number for the 9 characters since the record
number could be repeated if you delete a particular record. The
characters must be unique in the table.

Each memo in the table has to begin with a 19 character code made up
of upper case name of the memo field right paded to 10 characters plus
the 9 character unique mentioned above. Whenever you add a memo, your
application must make sure that there is the proper code at beginning
of the memo.

IMPORTANT: Please view enclosed SAMPLE2.DBF table to see how the R_TRACE_
code and memo code is implemented.
