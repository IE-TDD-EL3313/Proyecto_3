# Prueba del contrato CPU/memorias/MMIO; no es el programa de Batalla Naval.
.option norvc
.option norelax
.section .text
.global _start
_start:
    lui s0, 2                  # RAM
    lui s1, 0x10               # perifericos
    lui t0, 0x12345
    addi t0, t0, 0x678
    sw t0, 0(s0)
    addi s2, s0, 2047
    addi s2, s2, 2045          # ultima palabra RAM: 0x2ffc
    sw t0, 0(s2)
    lw t1, 0(s2)
    bne t0, t1, fail
    lw t1, 0(s0)
    bne t0, t1, fail
    addi t0, zero, 5
    sw t0, 0x138(s1)          # ejemplo: escribir LED
    lw t1, 0x120(s1)          # ejemplo: leer entradas J1
    sw t1, 4(s0)              # conservar dato leido en RAM
    lui t2, 0x11
    sw t1, 0(t2)              # ejemplo: una palabra hacia memoria VGA
    addi t0, zero, 1
    sw t0, 0x138(s1)          # marca fin correcto
done:
    jal zero, done
fail:
    addi t0, zero, 7
    sw t0, 0x138(s1)
    jal zero, fail
