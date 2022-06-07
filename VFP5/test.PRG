VersNo = Val(Substr(Version(), 15, 4))
compvers = 9
MESSAGEBOX("The selected .DBF file, a Visual FoxPro" + ALLT(STR(compvers)) + " table type,";
  + CHR(13) + "is incompatible with Visual FoxPro" + ALLT(STR(VersNo));
  + " you are now using.", 0, "Notice!")
