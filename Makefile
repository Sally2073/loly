ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
IGNORE_WARNINGS = 1
ROOTLESS = 1

ifeq ($(ROOTLESS), 1)
THEOS_PACKAGE_SCHEME = rootless
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = loly

loly_FILES = Tweak.xm Menu.xm
loly_CFLAGS = -fobjc-arc -w
loly_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG -w
loly_LDFLAGS = -lc

loly_LIBRARIES += substrate
loly_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText OpenGLES

include $(THEOS_MAKE_PATH)/tweak.mk

# Obfuscation
before-package::
	@echo "Running obfuscation..."
	@chmod +x obfuscate.sh 2>/dev/null || true
	@./obfuscate.sh 2>/dev/null || true

after-package::
	@echo "✅ Tweak packaged successfully!"

after-install::
	@install.exec "killall -9 SpringBoard || killall -9 loly || :"
