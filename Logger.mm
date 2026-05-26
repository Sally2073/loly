// Logger.mm
#include "Logger.h"
#include <stdarg.h>
#include <Foundation/Foundation.h>
#include <string.h>

std::map<std::string, int> logCount;

void logToFile(const char* format, ...) {
    va_list args;
    va_start(args, format);
    char buffer[1024];
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    std::string logMessage = buffer;

    // منع تكرار اللوغز (زي التصميم الأصلي)
    if (logCount[logMessage] > 0) {
        return;
    }
    logCount[logMessage]++;

    NSString *appDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *logPath = [appDir stringByAppendingPathComponent:@"general_storage/koky.log"];
    
    // حاول إنشاء المجلد
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:[logPath stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error) {
        fprintf(stderr, "Failed to create directory %s: %s\n", [logPath UTF8String], [[error localizedDescription] UTF8String]);
    }

    // حاول فتح الملف
    FILE *logFile = fopen([logPath UTF8String], "a");
    if (!logFile) {
        fprintf(stderr, "Failed to open log file %s: %s\n", [logPath UTF8String], strerror(errno));
        // جرب مسار بديل
        NSString *fallbackPath = @"/var/mobile/Media/Koky.log";
        logFile = fopen([fallbackPath UTF8String], "a");
        if (!logFile) {
            fprintf(stderr, "Failed to open fallback log file %s: %s\n", [fallbackPath UTF8String], strerror(errno));
            return;
        }
        logPath = fallbackPath; // استخدم المسار البديل لو نجح
    }

    fprintf(logFile, "[%s] %s\n", [[NSDate date] description].UTF8String, logMessage.c_str());
    fclose(logFile);
}