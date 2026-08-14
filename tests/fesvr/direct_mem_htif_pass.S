// Defines the inert RV32 payload used to exercise FESVR ELF loading and startup.
.section .text
.globl _start
_start:
  j _start

.section .tohost,"aw",@progbits
.balign 8
.globl tohost
tohost:
  .dword 0
.globl fromhost
fromhost:
  .dword 0
