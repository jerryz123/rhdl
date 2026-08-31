/* Places the executing RV5Stage smoke and its HTIF mailboxes in SimpleSoC RAM. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : { *(.text*) }

  . = 0x80001000;
  .tohost : { *(.tohost) }
}
