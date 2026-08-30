/* Places the transport smoke payload and HTIF mailboxes at deterministic addresses. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY_BASE = DEFINED(__memory_base) ? __memory_base : 0x80000000;

SECTIONS
{
  . = MEMORY_BASE;
  .text : { *(.text*) }

  . = MEMORY_BASE + 0x1000;
  .tohost : { *(.tohost) }
}
