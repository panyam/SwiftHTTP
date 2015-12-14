
# 
# Version/Product information
#
VERSION                 = 0.0.1
PRODUCT_NAME            = swiftli

# 
# Build directory
#
ifeq ($(OUTPUT_DIR),)
    OUTPUT_DIR          =   ./.build
endif

SWIFTC = swiftc
SWIFTCFLAGS = -I ./Sources

SOURCES = $(wildcard Sources/*.swift)
OBJECTS = $(foreach obj, $(patsubst %.swift,%.o,$(SOURCES)), $(OUTPUT_DIR)/$(obj))

# Implicit rule to build .o into the build directory from .swift
$(OUTPUT_DIR)/%.o : %.swift
	$(SWIFTC) -c $(SWIFTCFLAGS) $< -o $@

all: base $(OBJECTS)

base:
	@echo Sources: $(SOURCES)
	@echo Objects: $(OBJECTS)
	mkdir -p $(OUTPUT_DIR)
