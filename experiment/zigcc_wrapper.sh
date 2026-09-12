#!/bin/sh
# zigcc_wrapper.sh -- the C compiler the kernel is given (ZIGCC-1). It is
# `zig cc`, with every difference from a plain call stated here rather
# than hidden. $ZIGCC_REAL names the Linux zig fetched by digest
# (experiment/zigcc_fetch.sh).
#
# 1. -mtune=* is DROPPED. zig cc parses -march/-mcpu/-mtune itself, into
#    zig's own CPU model, and knows no CPU named "generic"; the kernel's
#    x86 Makefile passes -mtune=generic and the build stops at the first
#    object with "unknown target CPU 'generic'". -mtune is a scheduling
#    hint: it changes which instruction ordering the compiler prefers for
#    a CPU family, never what the program means.
#
# 2. -Wno-unused-command-line-argument is ADDED. zig cc makes that
#    warning an error, and the kernel's assembly rule passes flags the
#    assembly phase does not consume. Argument hygiene, not semantics.
#
# 3. An assembly request carrying a DEPENDENCY FILE is split into two
#    passes. Asked for both at once -- in either spelling, -Wp,-MMD,P or
#    -MMD -MF P -- zig cc writes the depfile, writes NO ASSEMBLY AT ALL,
#    and exits 0; the kernel then stops at "cannot open
#    devicetable-offsets.s". Isolated flag by flag on the kernel's own
#    failing command (experiment/zigcc_probe3.sh). So: pass one asks for
#    the assembly alone, pass two asks the preprocessor alone for the
#    dependencies (-E -MM -MF P -o /dev/null). Both outputs are real and
#    the depfile lists every header the source truly includes -- a
#    hundred of them for that file. Nothing is forged and nothing is
#    lost; the cost is one extra preprocessor run for the handful of
#    assembly targets a kernel build has.
#
# 4. The TARGET is changed, when the caller names a Linux triple and asks
#    for -fno-PIE -- the kernel's own signature. Three facts force it:
#      - zig cc compiles position-independent by default, and under PIC
#        the address of a symbol is not an immediate, so the kernel's
#        per-CPU accessors stop with "invalid operand for inline asm
#        constraint 'i'" in asm/current.h;
#      - on every LINUX target zig refuses -fno-pic outright: "the
#        selected target requires position independent code";
#      - on zig's FREESTANDING target for the same architecture,
#        -fno-pic is accepted and the kernel's own sources compile
#        clean, per-CPU accessors and integrated assembler included
#        (experiment/zigcc_probe6.sh).
#    So `--target=<arch>-linux-gnu` becomes `-target <arch>-freestanding`
#    plus -fno-pic. This is the largest concession here and the most
#    defensible: a kernel IS freestanding code, and the Linux triple is
#    what the kernel hands clang by convention, not a property of what it
#    is building. What it changes is the predefined macros of the host
#    OS, which a kernel does not consult (it defines __KERNEL__ itself).
#
# The arguments are rebuilt through the positional parameters and never
# through eval: the kernel passes flags whose values contain quotes
# (-DKBUILD_MODNAME='"x"'), and an eval would silently strip them.
: "${ZIGCC_REAL:?zigcc_wrapper: ZIGCC_REAL must name the zig binary}"

want_s=no
dep=""
prev=""
arch=""
nopie=no
extra="-Wno-unused-command-line-argument"
for a in "$@"; do
  case "$prev" in -MF) dep=$a ;; esac
  case "$a" in
    -S) want_s=yes ;;
    -Wp,-MMD,*) dep=${a#-Wp,-MMD,} ;;
    -Wp,-MD,*) dep=${a#-Wp,-MD,} ;;
    -fno-PIE|-fno-pie|-fno-pic|-fno-PIC) nopie=yes ;;
    -fPIC|-fpic|-fPIE|-fpie) wants_pic=yes ;;
    --target=*-linux-*) t=${a#--target=}; arch=${t%%-*} ;;
  esac
  prev=$a
done
# zig decides the PIC policy from the TARGET and holds to it: a Linux
# target requires position-independent code, a freestanding one forbids
# it. That divides the kernel tree in two, and the division is exactly
# the right one:
#   the kernel proper  asks for -fno-PIE and no PIC -> freestanding
#   the VDSO           asks for -fPIC, being a real shared object, and
#                      keeps the Linux target, where zig requires PIC
# Getting this wrong shows up at the VDSO link as "R_X86_64_32 against
# hidden symbol ... can not be used when making a shared object".
freestanding=no
if [ "$nopie" = yes ] && [ -n "$arch" ] && [ "${wants_pic:-no}" = no ]; then
  freestanding=yes
  extra="$extra -target $arch-freestanding -fno-pic"
fi

n=$#
i=0
skip=no
while [ $i -lt $n ]; do
  a=$1
  shift
  i=$((i + 1))
  if [ "$skip" = yes ]; then skip=no; continue; fi
  case "$a" in
    -mtune=*) continue ;;
    --target=*) [ "$freestanding" = yes ] && continue ;;
  esac
  if [ "$want_s" = yes ]; then
    case "$a" in
      -c|-MMD|-MD) continue ;;
      -Wp,-MMD,*|-Wp,-MD,*) continue ;;
      -MF) skip=yes; continue ;;
    esac
  fi
  set -- "$@" "$a"
done

if [ "$want_s" = yes ]; then
  # shellcheck disable=SC2086 -- $extra is a list of plain flags, by construction
  "$ZIGCC_REAL" cc "$@" $extra || exit $?
  if [ -n "$dep" ]; then
    "$ZIGCC_REAL" cc "$@" $extra -E -MM -MF "$dep" -o /dev/null || exit $?
  fi
  exit 0
fi
exec "$ZIGCC_REAL" cc "$@" $extra
