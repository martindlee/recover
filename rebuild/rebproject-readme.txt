Rebproject.scx/sct form description.

For general Rebuild utility instructions please read Rebuildhelp.txt

The Rebproject form may help you collect Rebuild.dbf/fpt and/or
NewRebuild.dbf/fpt initial table data and setup a rebuild file package
to send to your clients. The form will work with selected directories
or a file list - using either relative or absolute addressing.

It can also be used to collect file information for your local PC
Rebuild. However it will in those cases erase copies of
Rebuild.dbf/fpt and Rebuild.app from your working directories in the
process. You can modify the source code of this form to suit yourself.

To run this form, use the foxpro command window and type

DO FORM RebProject

The form Init method contains first few lines where you can define
Rebuild-List-File       ('RebuildList.txt')
NewRebuild-List-File    ('RebuildList.txt')
RebuildApp              ('Rebuild.app' or 'Rebuild9.exe')
FileListType            ('*FILELIST*' or '*EXCLUDELIST*')
Note that *EXCLUDELIST* works only from current directory

Main tab:
  Main operations
Rebuild, Recover, Gendef Option Codes tab:
  Use this to set your Rebuild/Recover/Gendef options
Instructions:
  The help tab giving this text.

To run the form just run it from a VFP command window
DO FORM RebProject

You are welcome to send suggestions for improving this form.
http://www.abri.com/email.html
