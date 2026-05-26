// SLINT.h
#pragma once

#ifndef SLINT_KEY
// مفتاح XOR بسيط + يتغير جزئيًا مع كل عملية تجميع (compile)
#define SLINT_KEY (0x5A ^ (__TIME__[0] + __TIME__[3] + __TIME__[6] + __COUNTER__))
#endif

// Macro قصير جدًا لتشفير السلاسل أثناء الـ compile-time
// الاستخدام: _("BattleManager")   أو   _("m_ShowPlayers")  إلخ
#define _(s) ([]() -> const char* {                                 \
    constexpr char key = SLINT_KEY;                                  \
    static char buf[sizeof(s)];                                      \
    static bool done = false;                                        \
    if (!done) {                                                     \
        for (size_t i = 0; i < sizeof(s); ++i)                       \
            buf[i] = (s)[i] ^ key;                                   \
        done = true;                                                 \
    }                                                                \
    return buf;                                                      \
}())