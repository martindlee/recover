#include <windows.h>
#include <stdio.h>
#pragma hdrstop
#include <winbase.h>
#include <math.h>
#include <string.h>

// UDF prototypes

char *Int2Str(int);
char *LongInt2Byte(unsigned long, int, int);
unsigned long Byte2LongInt(char *, unsigned long, int);
HANDLE lcreate(LPCSTR FileName);
HANDLE lopen(LPCSTR, DWORD);
DWORD lseek(HANDLE, LONG, DWORD);
BOOL lclose(HANDLE);
BOOL lread(HANDLE, LPVOID, DWORD);
BOOL lwrite(HANDLE, LPVOID, DWORD);
unsigned long GetValue(HANDLE, long int, DWORD, int);
BOOL PutValue(HANDLE, long int, unsigned long, DWORD, int);

//---------------------------------------------------------------------------
int
WINAPI WinMain(HINSTANCE, HINSTANCE,
LPSTR ParmString, // the whole parameter string - but not this program.exe
int)
{
// Used with Recover FPD/FPW to reduce 2MB+ files to below 2MB so that recover can fix it
if (strlen(ParmString) == 0){
  MessageBox(NULL, L"This is an associate Recover file and not the Recover main utility.", L"Notice.", 0);
  return 0;
  }
HANDLE hFile1 = lopen(ParmString, GENERIC_WRITE | GENERIC_READ);
if (hFile1==INVALID_HANDLE_VALUE){
  MessageBox(NULL, L"File to trim not found or not accessible.", L"Notice!", 0);
  return 0;}

if (GetFileSize(hFile1, NULL) > (DWORD)2147483647
    && lseek(hFile1, (LONG)2147483646, FILE_BEGIN) == (DWORD)2147483646){
    SetEndOfFile(hFile1);
    PutValue(hFile1, 4, GetValue(hFile1, 4, 4, 1) + 1, 4, 1); // change the record counter so that Recover gives a repair message
    MessageBox(NULL,
      L"For the 16 bit DOS and FPW Recover editions, 2GB+ file repair is a 2 step process. Please TURN OFF ALL OPTIONS EXCEPT: \"Check record file header\" and \"Header repair\" (for record file) and run Recover repair on this file again.",
      L"Notice", 0);
  }
else MessageBox(NULL, L"This step not necessary for this file.", L"Notice!", 0);

lclose(hFile1);
return 0;

}

// ** ----- Some other functions

char *Int2Str(int decm){
// converts decm integer to character string
static char buffer[200];
//double log10(double x)
int decm0, sign, LeftDigit;
if (decm < 0) {decm0 = -decm; sign = 1; buffer[0] = '-';} // account for minus sign
else {decm0 = decm; sign = 0;}
int DCount = (int)log10(double(decm0)) + 1;
for (int i = 0; i < DCount; i++){
  LeftDigit = (char)(decm0/pow(10, DCount - i - 1));
  buffer[i + sign] = LeftDigit + 48; // current left char
  decm0 = decm0 - (int)LeftDigit*lround(pow(10, DCount - i - 1));
  }
buffer[DCount + sign] = 0; // null terminated string
return buffer;
}

unsigned long Byte2LongInt(char *STRING, unsigned long strlen, int dirn){
//* converts Bytes string to integer value
//* If Dirn = -1 : normal calculator left to right digit significance
//* If Dirn = +1 : assembler memory addressing right to left significance
unsigned long RetVal = 0;
int A = 0, B = 0, i, j, ByteVal;
j=0;
if (dirn > 0) B = strlen - 1;
else A = strlen - 1;
for (i = A; i != B + dirn; i = i + dirn){
  if (STRING[j] < 0) ByteVal = 256 + STRING[j]; // character has signed value
  else ByteVal = STRING[j];
  RetVal = (ByteVal)*lround(pow(256, i)) + RetVal;
  j=j+1;}
return RetVal;}

//--------------
char *LongInt2Byte(unsigned long decm, int N, int dirn){
// Converts an integer number 'Decm', into a N byte string
// Left to right if Dirn = -1 and right to left if Dirn = 1
// Returns: the Byte String
static char retval[1024];
unsigned long num = decm, rem;
for (int i = 1; i < 1025; i++) retval[i] = 0; // intialize all to 0's
int counter = 0;
while (num > 255){
  rem = num % 16;
  if (dirn>0) retval[counter] = (char)(num%256);
  else  retval[N - counter - 1] = (char)(num%256);
  num = num/256;
  counter++;
  }
if (dirn>0) retval[counter] = (char)num;
else  retval[N - counter - 1] = (char)num;
return retval;
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

DWORD lseek(HANDLE hFile, LONG lDistanceToMove, DWORD dwMoveMethod)
{return SetFilePointer(hFile, lDistanceToMove, NULL, dwMoveMethod);}

BOOL lclose(HANDLE hObject) // short form
{return CloseHandle(hObject);}

BOOL lread(HANDLE hFile, LPVOID lpBuffer, DWORD nNBytesToRead)
{DWORD lpNBytesRead;
if (ReadFile(hFile, lpBuffer, nNBytesToRead, &lpNBytesRead, NULL))
  return lpNBytesRead; // successfull file read - but may be 0 bytes => EOF
else
  return -1;} // unsuccessfull read = -1

BOOL lwrite(HANDLE hFile, LPVOID lpBuffer, DWORD nNBytesToWrite)
{BOOL x; DWORD lpNBytesWritten;
x = WriteFile(hFile, lpBuffer, nNBytesToWrite, &lpNBytesWritten, NULL);
if (x) return lpNBytesWritten; // successfull file read - but may be 0 bytes => EOF
else return -1;}

//----
unsigned long GetValue(HANDLE hFile, long int FileLoc, DWORD nbytes, int dirn)
{
// Gets integer value from N bytes at file location FileLoc
char bfr[500];
lseek(hFile, FileLoc, FILE_BEGIN);
lread(hFile, bfr, nbytes);
return Byte2LongInt(bfr, nbytes, dirn);}

//----
BOOL PutValue(HANDLE hFile, long int FileLoc, unsigned long Intgr, DWORD nbytes, int dirn)
{
// Converts 'Intgr' value to nbytes and writes it at location FileLoc
// Returns true if bytes written
lseek(hFile, FileLoc, FILE_BEGIN);
return lwrite(hFile, LongInt2Byte(Intgr, nbytes, dirn), nbytes);}

