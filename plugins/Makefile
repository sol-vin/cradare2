R2_CFLAGS ?= $(shell r2 -H R2_CFLAGS 2>/dev/null || pkg-config --cflags r_core)
R2_LDFLAGS ?= $(shell r2 -H R2_LDFLAGS 2>/dev/null || pkg-config --libs r_core)
R2_USER_PLUGINS ?= $(shell r2 -H R2_USER_PLUGINS 2>/dev/null || echo ~/.local/share/radare2/plugins)
SO_EXT ?= $(shell r2 -H R2_LIBEXT 2>/dev/null || echo so)

TARGET = core_crystal.$(SO_EXT)

all: $(TARGET)

$(TARGET): core_crystal.c
	$(CC) $(CFLAGS) $(R2_CFLAGS) -shared -fPIC -o $@ $< $(R2_LDFLAGS) -lr_core -lr_util -lr_cons

install: $(TARGET)
	mkdir -p $(R2_USER_PLUGINS)
	cp -f $(TARGET) $(R2_USER_PLUGINS)/

clean:
	rm -f $(TARGET)

.PHONY: all install clean
