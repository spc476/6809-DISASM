AS09 = $(HOME)/source/6809/asm/la09.lua

% : %.a
	$(AS09) $(AS09FLAGS) -o $@ -l$(*F).list $<

.PHONY: all clean

all: disasm testdisasm

clean:
	$(RM) $(shell find . -name '*~')
	$(RM) $(shell find . -name '*.list')
	$(RM) disasm testdisasm
