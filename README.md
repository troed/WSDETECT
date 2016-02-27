Wakestate detect v1.0 by Troed/SYNC

As promised during my overscan and sync scroll talk at STNICCC 2015:
https://www.youtube.com/watch?v=F4WJYyoF1Lk

Here's a piece of code to detect which wakestate the machine is
currently in. It's done using a specially crafted scanline which due
to the combination and position of GLUE frequency and resolution
register changes creates a scanline of different length in ST 
wakestate 1,2,3,4 as well as on STE.

Feel free to include _detect_ws in your own code.

More information on how this works here:
http://www.atari-wiki.com/?title=ST_STE_Scanlines
