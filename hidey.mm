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
