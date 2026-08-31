// Exercises RV5Stage before reporting success through the standard HTIF mailbox.
.section .text
.globl _start
_start:
  li t0, 1
  la t1, tohost
  sd t0, 0(t1)
1:
  j 1b

.section .tohost,"aw",@progbits
.balign 8
.globl tohost
tohost:
  .dword 0
.globl fromhost
fromhost:
  .dword 0
