#!/bin/bash
echo "🔒 Starting FULL IL2CPP Automatic Obfuscation..."

# توليد أسماء عشوائية
RAND_ATTACH=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 4)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 14)
RAND_GETMETHOD=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 4)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 13)
RAND_GETFIELD=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 4)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
RAND_GETSTATIC=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 4)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 11)
RAND_GETIMAGE=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 4)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 13)
RAND_GETCLASSTYPE=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 4)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)

# === إنشاء hidey.h ===
cat > hidey.h << EOF
// ==================== AUTO GENERATED - FULL OBFUSCATION ====================
#ifndef HIDEY_H
#define HIDEY_H

#include <string>
#include <dlfcn.h>

std::string hidey_decrypt(std::string s, char key = 0xAB);
#define HIDE_STR(str) hidey_decrypt(str, 0xAB)

extern "C" void ${RAND_ATTACH}(const char* name);
extern void* ${RAND_GETMETHOD}(const char* image, const char* ns, const char* clazz, const char* method, int argsCount);
extern size_t ${RAND_GETFIELD}(const char* image, const char* ns, const char* clazz, const char* name);
extern unsigned long ${RAND_GETSTATIC}(const char* image, const char* ns, const char* clazz, const char* name);
extern void* ${RAND_GETIMAGE}(const char* image);
extern void* ${RAND_GETCLASSTYPE}(const char* image, const char* ns, const char* clazz);

#endif
EOF

# === إنشاء hidey.mm ===
cat > hidey.mm << 'EOF'
#include "hidey.h"
#include <dlfcn.h>
#include <Foundation/Foundation.h>

std::string hidey_decrypt(std::string s, char key) {
    for (char &c : s) c ^= key;
    return s;
}

extern "C" void ${RAND_ATTACH}(const char* name) {
    void* handle = dlopen("/System/Library/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY | RTLD_LOCAL);
    if (!handle) return;
    NSLog(@"[koky] hidey attach success");
}

void* ${RAND_GETIMAGE}(const char* image) { return NULL; }
void* ${RAND_GETCLASSTYPE}(const char* image, const char* ns, const char* clazz) { return NULL; }
void* ${RAND_GETMETHOD}(const char* image, const char* ns, const char* clazz, const char* method, int argsCount) { return NULL; }
size_t ${RAND_GETFIELD}(const char* image, const char* ns, const char* clazz, const char* name) { return -1; }
unsigned long ${RAND_GETSTATIC}(const char* image, const char* ns, const char* clazz, const char* name) { return 0; }
EOF

# === استبدال آمن باستخدام sed صحيح ===
if [ -f "Tweak.xm" ]; then
    sed -i '' "s/Il2CppAttach/${RAND_ATTACH}/g" Tweak.xm
    sed -i '' "s/Il2CppGetMethodOffset/${RAND_GETMETHOD}/g" Tweak.xm
    sed -i '' "s/Il2CppGetFieldOffset/${RAND_GETFIELD}/g" Tweak.xm
    sed -i '' "s/Il2CppGetStaticFieldOffset/${RAND_GETSTATIC}/g" Tweak.xm
    sed -i '' "s/Il2CppGetImageByName/${RAND_GETIMAGE}/g" Tweak.xm
    sed -i '' "s/Il2CppGetClassType/${RAND_GETCLASSTYPE}/g" Tweak.xm
    echo "✅ Successfully replaced functions in Tweak.xm"
else
    echo "⚠️  Tweak.xm not found!"
fi

echo "✅ FULL Obfuscation Completed!"
echo "   Attach       → ${RAND_ATTACH}"
echo "   GetMethod    → ${RAND_GETMETHOD}"
echo "   GetField     → ${RAND_GETFIELD}"