
#make -f makefile.mwrap -j12 TARGET=matlab-windows-w32-openmp clean
#make -f makefile.mwrap -j12 TARGET=matlab-windows-w32-openmp  

#make -f makefile.mwrap -j12 TARGET=matlab-windows-w64-openmp clean
#make -f makefile.mwrap -j12 TARGET=matlab-windows-w64-openmp 

#make -f makefile.mwrap -j12 TARGET=matlab-linux-a64-openmp clean
#make -f makefile.mwrap -j12 TARGET=matlab-linux-a64-openmp  

make -f makefile.mwrap -j12 TARGET=octave-linux-openmp clean
make -f makefile.mwrap -j12 TARGET=octave-linux-openmp 

make -f makefile.mwrap clean distclean

