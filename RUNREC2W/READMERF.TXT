Royalty free package in non FoxPro applications - 16 bit for Windows
====================================================================

Recover is written in FoxPro, but this package enables you to launch
Recover from non-FoxPro applications by calling the RecovPkg.exe from
your program or from windows (batch processing). This is accomplished
through the dBaseIII table RECOVLST.DBF (shared mode) in which you
indicate the tables you want repaired, Recover options you want to
use, and whether the table is to be done in a particular run.
RecovPkg.exe scans the table and launches Recover with corresponding
parameters for each entry.

Please read MANUAL.TXT file to learn how Recover works. Since you are
not running Recover from FoxPro you can ignore the programming method
suggestions and sample code.

The RECOVWIN.ZIP part of the package includes the additional necessary
FOXW2600.ESL (foxpro library file), CONFIG.FPW (optimal configuration
file) and runrecov.exe. The last file is only used for the single user
standalone package and can be deleted.

1) Filling in the RECOVLST.DBF table:
=====================================

With your database tool - or you can use the handy BROWSE.EXE - fill
in the dBaseIII table RECOVLST.DBF with the list of files to
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
DOGENDEF    Logical    1     Place T if you want def file made for this file - else F (false)

Note: Gendef will generate def files only for the records having DOTHISONE = T (true)


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

Note 2: If you prefer you can download the FPW2.6 demo package
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
in your application or some way to wait till RecovPkg.exe is done, so
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
records (PACK). The Browse title has the necessary command prompts. Or
you can use the Table menu.