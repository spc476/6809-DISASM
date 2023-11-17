# *************************************************************************
#
# Copyright 2013 by Sean Conner.
#
# This library is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at your
# option) any later version.
#
# This library is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this library; if not, see <http://www.gnu.org/licenses/>.
#
# Comments, questions and criticisms can be sent to: sean@conman.org
#
# *************************************************************************

# You'll need to replace the following with a 6809 assembler that at least
# supports FCS and the ability to handle line 760 of disasm.asm.

AS09      = $(HOME)/source/asm/a09/a09
AS09FLAGS = -nW0009 -l $(*F).list

% : %.asm
	$(AS09) $(AS09FLAGS) -o $@ $<

.PHONY: all clean

all: disasm testdisasm

clean:
	$(RM) $(shell find . -name '*~')
	$(RM) $(shell find . -name '*.list')
	$(RM) disasm testdisasm
