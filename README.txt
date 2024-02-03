
               The MC6809 Disassmebler in MC6809 Assembly Code

This implements a thread-safe, position independent, ROMable 2K routine to
disassemble a single MC6809 instruction.  The RAM requirements are minimal,
requiring only 47 bytes of stack, and 55 bytes of non-stack RAM in order to
operate.

Upon entry, the X register needs to point to 55 bytes of RAM, which will be
used to return the disassembly, and the Y register pointing to the
instruction to be decoded.  All registers are saved, except for Y, which
upon return, will point to the next instruction in memory.

The space provided by the X register will contain the following data upon
return:

	offset	contents
	0	pointer to address in hexadecimal format
	2	pointer to opcode bytes in hexadecimal format
	4	pointer to operand bytes in hexadecimal format
	6	pointer to opcode as text
	8	pointer to operand as text
	10+	ASCII text strings

Each string is terminated with a NUL byte.
