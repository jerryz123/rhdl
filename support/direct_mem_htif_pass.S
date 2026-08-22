// Defines an inert RV32 payload whose preloaded mailbox completes transport smokes.
.section .text
.globl _start
_start:
  j _start

.section .tohost,"aw",@progbits
.balign 8
.globl tohost
tohost:
  .dword 1
.globl fromhost
fromhost:
  .dword 0
