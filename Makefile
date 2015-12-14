
# 
# Version/Product information
#
MAJOR_VERSION           = @MAJOR_VERSION@
MINOR_VERSION           = @MINOR_VERSION@
BUILD_VERSION           = @BUILD_VERSION@
VERSION                 = $(MAJOR_VERSION).$(MINOR_VERSION).$(BUILD_VERSION)
PRODUCT_NAME            = swiftli

# 
# Build directory
#
ifeq ($(OUTPUT_DIR),)
    OUTPUT_DIR          =   ./.build
endif

SWIFTC = swiftc
SWIFTCFLAGS = 

SOURCES := $(foreach dir,Sources,$(shell find $(dir)/*.swift -printf "%p " 2> /dev/null))
OBJECTS = $(foreach obj, $(patsubst %.swift,%.o,$(SOURCES)), $(OUTPUT_DIR)/$(obj))

# Implicit rule to build .o into the build directory from .swift
$(OUTPUT_DIR)/%.o : %.swift
	$(SWIFTC) -c $(SWIFTCFLAGS) $< -o $@

all: base $(OBJECTS)

base:
	@echo Sources: $(SOURCES)
	@echo Objects: $(OBJECTS)
	mkdir -p $(OUTPUT_DIR)
