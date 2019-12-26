cl -c /I"%DRAGONFLY%\include" /I"%ROBOTINC%" /EHsc /TP /MD NetboxModule.cpp 

link /MANIFEST /LIBPATH:"%DRAGONFLY%\lib"  Dragonfly.lib  NetboxModule.obj  /OUT:NetboxModule.exe  

