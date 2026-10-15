#!/bin/bash
# Compila riscv-tests oficiales (entornos p y v) con clang/lld para rv64imac.
# Uso: build_tests.sh <ruta riscv-tests> <dir salida>
# Diferencias con el flujo GNU (documentadas):
#  - LLVM no permite redefinir como global un simbolo .weak: si el test define
#    mtvec_handler/stvec_handler se borra el .weak tras preprocesar.
#  - 'tcontrol' no lo conoce llvm-mc: se sustituye por su numero 0x7a5.
#  - -msmall-data-limit=0: con lld el .sbss del kernel de vm.c cae en la
#    misma pagina que tdat y evict() lo detecta como escritura sin bit D.
#  - vm.c (entorno v) contiene un fssr que nunca se ejecuta: -march con F solo ahi.
set -u
RT=$1; OUT=$(realpath -m $2); mkdir -p $OUT/pp; : > $OUT/build.log
STUB=$(dirname $(realpath $0))/libc_stub
BASE="clang -msmall-data-limit=0 --target=riscv64-unknown-elf -mabi=lp64 -mcmodel=medany -mno-relax -ffreestanding -isystem $STUB"
LINK="-nostdlib -nostartfiles -static -fuse-ld=lld"
ok=0; bad=0
pp() {  # $1 fuente .S, $2 env, $3 salida .s
  $BASE -march=rv64imac_zicsr_zifencei -E -x assembler-with-cpp -I$RT/env/$2 -I$RT/isa/macros/scalar $1 -o $3 || return 1
  for h in mtvec_handler stvec_handler; do
    grep -q "^ *$h:" $3 && sed -i "s/\.weak $h;//" $3
  done
  sed -i 's/\btcontrol\b/0x7a5/g' $3
}
for suite in rv64ui rv64um rv64ua rv64uc rv64mi rv64si; do
  for s in $RT/isa/$suite/*.S; do
    t=$(basename $s .S)
    if pp $s p $OUT/pp/$suite-p-$t.s 2>>$OUT/build.log && \
       $BASE -march=rv64imac_zicsr_zifencei $LINK -T$RT/env/p/link.ld $OUT/pp/$suite-p-$t.s -o $OUT/$suite-p-$t 2>>$OUT/build.log
    then ok=$((ok+1)); else bad=$((bad+1)); echo "FALLO $suite-p-$t" >>$OUT/build.log; fi
    case $suite in rv64u*)
      if pp $s v $OUT/pp/$suite-v-$t.s 2>>$OUT/build.log && \
         $BASE -march=rv64imafc_zicsr_zifencei -O2 $LINK -DENTROPY=0x$(echo $t|md5sum|cut -c1-7) -I$RT/env/v -T$RT/env/v/link.ld \
           $RT/env/v/entry.S $RT/env/v/vm.c $RT/env/v/string.c $OUT/pp/$suite-v-$t.s -o $OUT/$suite-v-$t 2>>$OUT/build.log
      then ok=$((ok+1)); else bad=$((bad+1)); echo "FALLO $suite-v-$t" >>$OUT/build.log; fi;;
    esac
  done
done
echo "compilados=$ok fallidos=$bad"
