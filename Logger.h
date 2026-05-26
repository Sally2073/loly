#ifndef LOGGER_H
#define LOGGER_H

#include <string>
#include <map>

extern std::map<std::string, int> logCount;
void logToFile(const char* format, ...);

#endif