// fm2gp: Fix Memofiles 2gig+
// AFTER .dbf has been corrected to below 2 gig
// this recovers memos from .fpt file over 2 gig
// AND then reduces it to below 2 gig

#include <windows.h>

#include <stdio.h>
#pragma hdrstop
#include <WinBase.h>
//#include <condefs.h>
#include <math.h>
#include <string.h>

// UDF prototypes
HANDLE lcreate(LPCSTR);
HANDLE lopen(LPCSTR, DWORD);
DWORD lseek(HANDLE, DWORD, DWORD);
BOOL lclose(HANDLE);
int lread(HANDLE, LPVOID, DWORD);
DWORD lwrite(HANDLE, LPVOID, DWORD);
                            
void MBox(LPCWSTR);
void CopyStr(char *, char *, int);
int Str2Int(PSTR, int);
PSTR Int2Str(double, int); // will take integers and double too
PSTR Dwd2Str(double, int);
PSTR Int2Bytes(DWORD, int, int);
DWORD Bytes2Int(PSTR, int, int);
DWORD GetValue(HANDLE, DWORD, DWORD, int);
DWORD PutValue(HANDLE, DWORD, unsigned, DWORD, int);
PSTR GetString(HANDLE, DWORD, DWORD);
DWORD PutString(HANDLE, DWORD, PSTR, DWORD);

//---------------------------------------------------------------------------
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
LPSTR ParmString, // the whole parameter string - but not this program.exe
int nShowCmd)
{
// GetValue/PutValue, GetString/PutString, Int2Bytes/Bytes2Int, OK.

struct Fprop {// table field properties structure
  char fname[11]; // field name - allow 0 termination string 
  char ftype; // field type
  int fpos; // field position in record
  int fwidth; // field width
  int fdec; // field decimals
  char fval[255]; // field contents
};

struct Fprop FldProp[19]={
  {"__________", ' ', 0,  0, 0, " "}, // do not use subscript 0
  {"USER_NAME ", 'C', 1, 15, 0, " "}, // this is field 1
  {"UPDATE_DT ", 'D', 16, 8, 0, " "},
  {"BEG_TIME  ", 'N', 24, 5, 0, " "},
  {"BEG_TM_ALP", 'C', 29, 8, 0, " "},
  {"END_TIME  ", 'N', 37, 5, 0, " "},
  {"END_TM_ALP", 'C', 42, 8, 0, " "},
  {"ID_CODE   ", 'C', 50, 7, 0, " "},
  {"NAME      ", 'C', 57, 25, 0, " "},
  {"EXISTG_CUS", 'C', 82, 1, 0, " "},
  {"NEW_RECORD", 'L', 83, 1, 0, " "},
  {"ACTION    ", 'C', 84, 50, 0, " "},
  {"RECORD_NO ", 'N', 134, 8, 0, " "},
  {"MULT_SAVES", 'N', 142, 3, 0, " "},
  {"DOC_NOTES ", 'M', 145, 10, 0, " "}, //14
  {"CHANGES   ", 'M', 155, 10, 0, " "}, //15
  {"CHAR_TYPED", 'N', 165, 5, 0, " "},
  {"NEW_INT_LV", 'N', 170, 2, 0, " "},
  {"ORG_INT_LV", 'N', 172, 2, 0, " "}
};

//char *binarystring = "\x01\x00\x32" "mary had a lamb"; // example how to mix hex string with characters
// HIWORD, LOWORD, MAKELONG examples:
//   DWORD x = MAKELONG(8589934,592);
//   int y = HIWORD(8589934592);
//   int z = LOWORD(x);

HANDLE DBFhandle = lopen("vidrevis.dbf", GENERIC_WRITE | GENERIC_READ),
Memohandle = lopen("vidrevis.fpt", GENERIC_WRITE | GENERIC_READ),
DBFhandleR = lcreate("vidrevisr.dbf"),
MemohandleR = lcreate("vidrevisr.fpt");

//int FileType = GetValue(hFile, 0, 1, 1), // file type 3 = dBase, 48 = Vis Fox, 245 = dBase w/memo
//     FirstRecPos1 = GetValue(hFile1, 8, 2, 1),  // first rec pos
//     RecordLen1   = GetValue(hFile1,10, 2, 1), // record length
//     RecCount1    = GetValue(hFile1, 4, 4, 1); // Records (1) shown in header
//DWORD FileEnd1     = lseek(hFile1, 0, FILE_END) + 1;
// mBlockSize=VAL(RecoverDef.WIDTH)
int FileType = 245, //= GetValue(hFile, 0, 1, 1), // file type 3 = dBase, 48 = Vis Fox, 245 = dBase w/memo
    FirstRecPos = 609,
    RecordLen = 174,
    FCount = 18,
    mBlockSize = 64;
DWORD mFileSize = GetFileSize(Memohandle, NULL); // NULL good up to 4gig
char MemoType[5] = "\x00\x00\x00\x01"; // ordinary memo type - should get this from .def file or memo pos.

char RecordString[65535];
int Recnum, mBlockNo, NextBlock = 8, mSize = 0, mTotSpace;
DWORD mPos0, mPos; // memo positions, old/new
                                                
PutString(MemohandleR, 0, GetString(Memohandle, 0, 512), 512); // copy memoheader

PutString(DBFhandleR, 0, GetString(DBFhandle, 0, 609), 609); //copy DBFheader + little more
int NewRec = 1;
for (Recnum = 1; Recnum < 775522; Recnum++){
  //if  (Recnum % 10000 == 0) MBox(Int2Str(Recnum, 20)); // test only

  CopyStr(GetString(DBFhandle, FirstRecPos + (Recnum-1)*RecordLen, RecordLen), // retrieve record
     RecordString, RecordLen); // to record buffer
  //PutString(DBFhandleR, FirstRecPos + 0, sptr+FldProp[14].fpos, FldProp[14].fwidth);
  for (int j = 1; j <= FCount; j++){
    mBlockNo = Str2Int(RecordString + FldProp[j].fpos, FldProp[j].fwidth);
    if (FldProp[j].ftype=='M' && mBlockNo != 0){
      mPos0 = (DWORD)((DWORD)mBlockNo*(DWORD)mBlockSize); // memo pos in old .FPT - includes front memo info
      mPos  = (DWORD)((DWORD)NextBlock*(DWORD)mBlockSize); // memo pos in new .FPT
      mSize = GetValue(Memohandle, mPos0 + 4, 4, -1);
      mTotSpace = (int)ceil((float)(mSize + 8)/(float)mBlockSize)*mBlockSize; // how much space reserved by whole memo thing
      //GetString(Memohandle, mPos0 + 8, mTotSpace -8)
      PutString(MemohandleR, mPos, GetString(Memohandle, mPos0, mTotSpace), mTotSpace);
      CopyStr(Int2Str(NextBlock, 10), RecordString + FldProp[j].fpos, 10); // change this for VFP
      //MBox(Int2Str(mPos, 20)); // test only
      NextBlock = NextBlock + lround(ceil((float)(mSize + 8) / (float)mBlockSize));
    }
  }
  PutString(DBFhandleR, FirstRecPos + (NewRec-1)*RecordLen, RecordString, RecordLen);
  NewRec++;
}
//MessageBox(NULL, sptr,  "Notice.", 0); // test only
lclose(DBFhandle); lclose(Memohandle); lclose(DBFhandleR); lclose(MemohandleR);
return 0;

//** Write surplus .FPT **
//FileHandle=lcreate("RecoverM.FPT")
// 0-3: NextFreeBlock, 6-7: BlockSize, blanks - 64byte blocksize, block 8 NextFree
// =lwrite(FileHandle, REPLICATE(CHR(0), 3)+CHR(8)
//  + REPLICATE(CHR(0), 3)+CHR(64)
//  + REPLICATE(CHR(0), 504))


}

// ** --- Simplified File i/o UDFs --- **
HANDLE lcreate(LPCSTR FileName)
{return CreateFileA(
    FileName,	// pointer to name of the file
    GENERIC_READ | GENERIC_WRITE,	// access (read-write) mode
    0,	// exclusive access only - no share mode
    NULL,	// pointer to security attributes
    CREATE_ALWAYS,	// how to create
    FILE_ATTRIBUTE_NORMAL,	// file attributes
    NULL // handle to file with attributes to copy
   );}

HANDLE lopen(LPCSTR FileName, DWORD Access)
{return CreateFileA(
    FileName,	// pointer to name of the file
    Access,	// access (read-write) mode
    0,	// exclusive access - no share mode
    NULL,	// pointer to security attributes
    OPEN_EXISTING,	// how to create
    FILE_ATTRIBUTE_NORMAL,	// file attributes
    NULL // handle to file with attributes to copy
   );}
                                                 
DWORD lseek(HANDLE hFile, // unsigned
   DWORD lDistanceToMove, //
   DWORD dwMoveMethod) {
DWORD lDist = lDistanceToMove;
if (dwMoveMethod == FILE_BEGIN && lDistanceToMove > 2147483647)
{ // solve large distance move with incremental seek
  SetFilePointer(hFile, (LONG)2147483647, NULL, FILE_BEGIN);
  lDist = lDist - 2147483647;
  while (lDist > 2147483647) {
    SetFilePointer(hFile, (LONG)2147483647, NULL, FILE_CURRENT);
    lDist = lDist - 2147483647;
  }
  return SetFilePointer(hFile, lDist, NULL, FILE_CURRENT); // move the remaining distance
}
else return SetFilePointer(hFile, (LONG)lDistanceToMove, NULL, dwMoveMethod);}

BOOL lclose(HANDLE hObject) // short form
{return CloseHandle(hObject);}

int lread(HANDLE hFile, LPVOID lpBuffer, DWORD nNBytesToRead)
{DWORD lpNBytesRead;
if (ReadFile(hFile, lpBuffer, nNBytesToRead, &lpNBytesRead, NULL))
  return (int)lpNBytesRead; // successfull file read - but may be 0 bytes => EOF
else
  return 0;} // unsuccessfull read = 0

DWORD lwrite(HANDLE hFile, LPVOID lpBuffer, DWORD nNBytesToWrite)
{DWORD lpNBytesWritten;
if (WriteFile(hFile, lpBuffer, nNBytesToWrite, &lpNBytesWritten, NULL))
  return lpNBytesWritten; // successfull file read - but may be 0 bytes => EOF
else
  return 0;} // unsuccessfull write = 0

//----

// ** ----- other functions

void MBox(LPCWSTR Msg)
{MessageBox(NULL, Msg, (LPCWSTR)"Notice.", 0);} // simplified message box

void CopyStr(char *src, char *dest, int nbytes)
{// copies nbytes from src at src to dest at dest - nut a null terminated string
  for (int i = 0; i < nbytes; i++) *(dest + i) = *(src + i);}

// (note: PSTR ptr = char *ptr)
int Str2Int(PSTR ptr, int n) // converts n character num rep to int.
{// eg. "3456" with n=4 is converted to retval=3456
  int i, retval=0;
  for (i=0;i<n;i++){
    // ignore characters outside '0123456789'
    if (*(ptr+i)-'0' < 10 && *(ptr+i)-'0' > -1) retval=retval*10+*(ptr+i)-'0';
  }
  return retval;
}

PSTR Int2Str(double decm, int n){// PSTR Int2Str = char *Int2Str
// converts decm integer to character string using n spaces total
static char buffer[2000];
//double log10(double x)
double decm0;
int sign, LeftDigit;

if (decm == 0) {for (int i=0; i<n; i++) buffer[i] = ' ';buffer[n-1] = '0'; buffer[n] = 0; return buffer;}

if (decm < 0) {decm0 = -decm; sign = 1;}
else {decm0 = decm; sign = 0;}
int DCount = (int)log10(decm0) + 1; // decimal digit count
int DPadCount = n - DCount;
if (decm < 0) buffer[sign + DPadCount - 1] = '-';  //account for minus sign
for (int i = 0; i < DPadCount; i++) buffer[i] = ' '; // change to ' ' later
for (int i = 0; i < DCount; i++){
  LeftDigit = (char)(decm0/pow(10, DCount - i - 1));
  buffer[i + sign + DPadCount] = LeftDigit + 48; // current left char
  decm0 = decm0 - (int)LeftDigit*pow(10, DCount - i - 1);
  }
buffer[DCount + sign + DPadCount] = 0; // null terminated string
return buffer;
}

PSTR Dwd2Str(double decm, int n){
// converts decm integer (to 2^32) to character string using n spaces total
static char buffer[200];
//double log10(double x)
double decm0 = decm; //4294967296;
int LeftDigit;
if (decm0 > 1.0) MBox((LPCWSTR)"Greater than 1"); else MBox((LPCWSTR)"Smaller than 1");


int DCount = (int)log10(decm0) + 1; // decimal digit count  (long double)decm0

//DCount = (int) log10((double)decm0);

MBox((LPCWSTR)Int2Str((int)DCount, 20));
int DPadCount = n - DCount;
for (int i = 0; i < DPadCount; i++) buffer[i] = ' '; // pad with front blanks
MBox((LPCWSTR)Int2Str(DCount, 10));
for (int i = 0; i < DCount; i++){
  MBox((LPCWSTR)Int2Str(DCount - i - 1, 10));
  LeftDigit = (char)(decm0/pow(10, DCount - i - 1));
  buffer[i + DPadCount] = LeftDigit + 48; // current left char
  decm0 = decm0 - ((int)LeftDigit*pow(10, DCount - i - 1));
}
MBox((LPCWSTR)"finish");
buffer[DCount + DPadCount] = 0; // null terminated string
return buffer;
}

DWORD Bytes2Int(PSTR STRING, int strlen, int dirn){
//* converts Bytes string to integer value
//* If Dirn = -1 : normal calculator left to right digit significance
//* If Dirn = +1 : assembler memory addressing right to left significance
unsigned RetVal = 0;
int A = 0, B = 0, i, j, ByteVal;
j=0;
if (dirn > 0) B = strlen - 1;
else A = strlen - 1;
for (i = A; i != B + dirn; i = i + dirn){
  if (STRING[j] < 0) ByteVal = 256 + STRING[j]; // char has signed value
  else ByteVal = STRING[j];
  RetVal = (ByteVal)*lround(pow(256, i)) + RetVal;
  j=j+1;}
return RetVal;}

//--------------
PSTR Int2Bytes(unsigned long decm, int Nbytes, int dirn){
// Converts an integer number 'Decm', into a N byte string
// Left to right if Dirn = -1 and right to left if Dirn = 1 (Assembler address method)
// Returns: the Byte String
static unsigned char retval[1030]; // ??? should that be static 'byte'???
unsigned long num = decm;
for (int i = 1; i < 1025; i++) retval[i] = 0; // intialize all to 0's
int counter = 0;
while (num > 255){
  if (dirn>0) retval[counter] = (char)(num%256);
  else  retval[Nbytes - counter - 1] = (char)(num%256);
  num = num/256;
  counter++;
  }
if (dirn>0) retval[counter] = (char)num;
else  retval[Nbytes - counter - 1] = (char)num;
return (PSTR)retval;
}

DWORD GetValue(HANDLE hFile, DWORD FileLoc, DWORD nbytes, int dirn)
{
// Gets integer value from N bytes at file location FileLoc
char bfr[500]; DWORD loc;
loc = lseek(hFile, FileLoc, FILE_BEGIN);
lread(hFile, bfr, nbytes);
return Bytes2Int(bfr, nbytes, dirn);}

//----
DWORD PutValue(HANDLE hFile, DWORD FileLoc, unsigned Intgr, DWORD nbytes, int dirn)
{
// Converts 'Intgr' value to nbytes and writes it at location FileLoc
// Returns number of bytes written or -1 for fail
lseek(hFile, FileLoc, FILE_BEGIN);
return lwrite(hFile, Int2Bytes(Intgr, nbytes, dirn), nbytes);}

PSTR GetString(HANDLE hFile, DWORD FileLoc, DWORD nbytes)
{// retreives string length nbytes at file location FileLoc
// important for calling program to keep track of bytecount (nbytes)
// or will run on past string
static char bfr[65501];
lseek(hFile, FileLoc, FILE_BEGIN);
lread(hFile, bfr, nbytes);
return bfr; //test mode
}

DWORD PutString(HANDLE hFile, DWORD FileLoc, PSTR bfr, DWORD nbytes)
{// writes nbytes string in pointer bfr at file location FileLoc
lseek(hFile, FileLoc, FILE_BEGIN);
return lwrite(hFile, bfr, nbytes);
}


// GetRec(), To get a record into string, use:
// RecBfrPointer = GetString(hFile, FirstRecPos + (Recnum-1)*RecordLen, RecordLen);

// PutRec(), To put a record in a string, use:
// BytesWritten = PutString(hFile, FirstRecPos + (Recnum-1)*RecordLen, RecordString, RecordLen);

// converting DBF pointer string to block number: = IIF(VFP, Bytes2Int(TempS, 1), VAL(TempS))

// converting block number to DBF pointer string: IIF(VFP, Int2Bytes(Value, 4, 1), STR(Value,10) ));

