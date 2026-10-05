OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { ROM (rx) : ORIGIN = 0x00000000, LENGTH = 8K }
SECTIONS {
  .text : { *(.text*) *(.rodata*) } > ROM
  /DISCARD/ : { *(.riscv.attributes) *(.comment) }
}
