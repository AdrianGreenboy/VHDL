\ conc.fs - lock-free stack (LPUSH/LPOP: 128-bit pointer|version head, LR.Q/SC.Q)
\ and the timer interrupt hook (ISR! TIMER TICKS)
: LCOUNT ( head -- n ) @ MASK64 AND 0 SWAP BEGIN DUP WHILE SWAP 1+ SWAP @ REPEAT DROP ;
: LTAG ( head -- n ) @ 64 RSHIFT ;
