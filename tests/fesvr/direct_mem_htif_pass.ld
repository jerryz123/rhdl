/* Places the transport-test payload and HTIF mailboxes at deterministic RV32 addresses. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : { *(.text*) }

  . = 0x80001000;
  .tohost : { *(.tohost) }
}
