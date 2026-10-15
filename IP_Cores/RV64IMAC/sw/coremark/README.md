# CoreMark bare-metal (RV64IMAC)

    COREMARK=<coremark> ITER=10 ./build.sh
    python3 ../../iss64.py --max 60000000 coremark_10.elf     # ISS, prints the report
    python3 ../../compare.py --tb cpu --timeout 40000000 coremark_10.elf   # RTL lockstep

CRCs for the performance seeds are correct (list 0xe714, matrix 0x1fd7, state 0x8e3a).
"Errors detected" with few iterations is only CoreMark's "must run >= 10 s" rule.
Measured: 9.34 M cycles / 10 iterations = ~1.07 CoreMark/MHz.
