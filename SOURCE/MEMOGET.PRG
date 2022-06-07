PARAMETER MemoText
* Retrieves user memopart in memos with Recover MemoTracers
RETURN IIF(LEN(MemoText)<20, '', SUBSTR(MemoText, 20))
