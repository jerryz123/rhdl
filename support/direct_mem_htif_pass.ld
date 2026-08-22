/* Places the transport smoke payload and HTIF mailboxes at deterministic addresses. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : { *(.text*) }

  . = 0x80001000;
  .tohost : { *(.tohost) }
}
