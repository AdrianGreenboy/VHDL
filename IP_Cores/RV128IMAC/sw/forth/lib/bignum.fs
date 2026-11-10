\ bignum.fs - arbitrary precision on 128-bit limbs (little-endian limb arrays)
\ asm primitives: BN0 BNCOPY BN0= BN+ BN- BN*1 BN/1 BN*
CREATE BNT 640 CELLS ALLOT
: BNLEN ( a n -- n' ) BEGIN DUP 0 > IF 2DUP 1- CELLS + @ 0= ELSE 0 THEN WHILE 1- REPEAT NIP ;
: BN. ( a n -- ) >R BNT R@ BNCOPY R> 0 SWAP
  BEGIN BNT SWAP BNLEN DUP WHILE >R BNT BNT R@ E19 BN/1 SWAP 1+ R> REPEAT DROP
  DUP 0= IF DROP 48 EMIT EXIT THEN
  1- SWAP .N BEGIN DUP WHILE 1- SWAP 19 .0 REPEAT DROP ;
: BN1 ( a n -- ) OVER SWAP BN0 1 SWAP ! ;
: BNFACT ( k a n -- ) 2DUP BN1 ROT 1+ 2 DO OVER DUP 2 PICK I BN*1 DROP LOOP 2DROP ;
\ pi by Machin: pi = 16 atan(1/5) - 4 atan(1/239), fixed point with PN limbs
\ (the top limb is the integer part)
VARIABLE PN VARIABLE PSIGN VARIABLE PK VARIABLE PH
CREATE PS 64 CELLS ALLOT  CREATE PT 64 CELLS ALLOT  CREATE PU 64 CELLS ALLOT
: TOP ( a -- addr ) PN @ 1- CELLS + ;
: ATAN+ ( mult k sign -- ) PSIGN ! PK ! PT PN @ BN0 PT TOP ! PT PT PN @ PK @ BN/1 DROP
  1 BEGIN PT PN @ BN0= 0= WHILE
    PT PU PN @ 3 PICK BN/1 DROP
    PSIGN @ 0< IF PS PU PS PN @ BN- ELSE PS PU PS PN @ BN+ THEN DROP
    PSIGN @ NEGATE PSIGN !
    PT PT PN @ PK @ DUP * BN/1 DROP
    2 +
  REPEAT DROP ;
: PI-COMPUTE ( limbs -- ) PN ! PS PN @ BN0 16 5 1 ATAN+ 4 239 -1 ATAN+ ;
: PI. ( chunks -- ) PS TOP @ .N 46 EMIT 0 PH !
  0 DO PS PS PN @ 1- E19 BN*1 DUP 19 .0 PH @ 31 * + PH ! LOOP ;
