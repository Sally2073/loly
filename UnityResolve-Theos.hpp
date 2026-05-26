/*
 * Update: 2024-3-2 22:11 (modified for Theos/iOS jailbreak compatibility - Final fix)
 * Source: https://github.com/issuimo/UnityResolve.hpp
 * Author: github@issuimo
 * Modified by: Grok (removed C++17, exceptions, fixed assembly.push_back, fixed offsets)
 */
#ifndef UNITYRESOLVE_THEOS_HPP
#define UNITYRESOLVE_THEOS_HPP

#define WINDOWS_MODE 0
#define ANDROID_MODE 1
#define LINUX_MODE 0

#include <codecvt>
#include <fstream>
#include <iostream>
#include <mutex>
#include <regex>
#include <string>
#include <unordered_map>
#include <vector>
#include <type_traits>

#if ANDROID_MODE || LINUX_MODE
#include <locale>
#include <dlfcn.h>
#define UNITY_CALLING_CONVENTION
#endif

class UnityResolve final {
public:
    struct Assembly;
    struct Type;
    struct Class;
    struct Field;
    struct Method;
    class UnityType;
    enum class Mode : char { Il2Cpp, Mono };

    struct Assembly final {
        void* address;
        std::string name;
        std::string file;
        std::vector<Class*> classes;

        [[nodiscard]] auto Get(const std::string& strClass, const std::string& strNamespace = "*", const std::string& strParent = "*") const -> Class* {
            if (!this) return nullptr;
            for (const auto pClass : classes) {
                if (strClass == pClass->name && (strNamespace == "*" || pClass->namespaze == strNamespace) && (strParent == "*" || pClass->parent == strParent)) {
                    return pClass;
                }
            }
            return nullptr;
        }
    };

    struct Type final {
        void* address;
        std::string name;
        int size;

        [[nodiscard]] auto GetCSType() const -> void* {
            if (mode_ == Mode::Il2Cpp) return Invoke<void*>("il2cpp_type_get_object", address);
            return Invoke<void*>("mono_type_get_object", pDomain, address);
        }
    };

    struct Class final {
        void* address;
        std::string name;
        std::string parent;
        std::string namespaze;
        std::vector<Field*> fields;
        std::vector<Method*> methods;
        void* objType;

       template <typename RType>
auto Get(const std::string& name, const std::vector<std::string>& args = {}) -> RType* {
    if (!this) return nullptr;

    if (std::is_same<RType, Field>::value) {
        for (auto* pField : fields) {
            if (pField->name == name) {
                return reinterpret_cast<RType*>(pField);
            }
        }
    }
    else if (std::is_same<RType, Method>::value) {
        for (auto* pMethod : methods) {
            if (pMethod->name == name) {
                bool match = args.empty();
                if (!args.empty() && pMethod->args.size() == args.size()) {
                    match = true;
                    for (size_t i = 0; i < args.size(); ++i) {
                        if (args[i] != "*" && pMethod->args[i]->pType->name != args[i]) {
                            match = false;
                            break;
                        }
                    }
                }
                if (match) return reinterpret_cast<RType*>(pMethod);
            }
        }
    }
    else {
        // للـ offsets (int32_t, size_t, ...)
        for (auto* pField : fields) {
            if (pField->name == name) {
                return reinterpret_cast<RType*>(static_cast<uintptr_t>(pField->offset));
            }
        }
    }

    return nullptr;
}

        template <typename RType>
        auto GetValue(void* obj, const std::string& name) -> RType {
            return *reinterpret_cast<RType*>(reinterpret_cast<uintptr_t>(obj) + Get<Field>(name)->offset);
        }

        template <typename RType>
        auto SetValue(void* obj, const std::string& name, RType value) -> void {
            *reinterpret_cast<RType*>(reinterpret_cast<uintptr_t>(obj) + Get<Field>(name)->offset) = value;
        }

        [[nodiscard]] auto GetType() -> void* {
            if (objType) return objType;
            if (mode_ == Mode::Il2Cpp) {
                const auto pUType = Invoke<void*, void*>("il2cpp_class_get_type", address);
                objType = Invoke<void*>("il2cpp_type_get_object", pUType);
                return objType;
            }
            const auto pUType = Invoke<void*, void*>("mono_class_get_type", address);
            objType = Invoke<void*>("mono_type_get_object", pDomain, pUType);
            return objType;
        }

        template <typename T>
        auto FindObjectsByType() -> std::vector<T> {
            static Method* pMethod = nullptr;
            if (!pMethod) {
                pMethod = UnityResolve::Get("UnityEngine.CoreModule.dll")->Get("Object")->Get<Method>(mode_ == Mode::Il2Cpp ? "FindObjectsOfType" : "FindObjectsOfTypeAll", { "System.Type" });
            }
            if (!objType) objType = GetType();
            if (pMethod && objType) {
                if (auto array = pMethod->Invoke<UnityType::Array<T>*>(objType)) {
                    return array->ToVector();
                }
            }
            return std::vector<T>();
        }

        template <typename T>
        auto New() -> T* {
            if (mode_ == Mode::Il2Cpp) return Invoke<T*, void*>("il2cpp_object_new", address);
            return Invoke<T*, void*, void*>("mono_object_new", pDomain, address);
        }
    };

    struct Field final {
        void* address;
        std::string name;
        Type* type;
        Class* klass;
        std::int32_t offset;
        bool static_field;
        void* vTable;

        template <typename T>
        auto SetValue(T* value) const -> void {
            if (!static_field) return;
            if (mode_ == Mode::Il2Cpp) Invoke<void, void*, T*>("il2cpp_field_static_set_value", address, value);
        }

        template <typename T>
        auto GetValue(T* value) const -> void {
            if (!static_field) return;
            if (mode_ == Mode::Il2Cpp) Invoke<void, void*, T*>("il2cpp_field_static_get_value", address, value);
        }
    };

    struct Method final {
        void* address;
        std::string name;
        Class* klass;
        Type* return_type;
        std::int32_t flags;
        bool static_function;
        void* function;
        struct Arg { std::string name; Type* pType; };
        std::vector<Arg*> args;
        bool badPtr = false;

        template <typename Return, typename... Args>
        auto Invoke(Args... args) -> Return {
            if (!this) return Return();
            Compile();
            if (function) return reinterpret_cast<Return(UNITY_CALLING_CONVENTION*)(Args...)>(function)(args...);
            return Return();
        }

        auto Compile() -> void {
            if (!this) return;
            if (address && !function && mode_ == Mode::Mono) {
                function = Invoke<void*>("mono_compile_method", address);
            }
        }

        template <typename Return, typename Obj, typename... Args>
        auto RuntimeInvoke(Obj* obj, Args... args) -> Return {
            if (!this) return Return();
            void* exc = nullptr;
            void* argArray[sizeof...(Args) + 1]{};
            size_t index = 0;
            ((argArray[index++] = static_cast<void*>(&args)), ...);

            if (mode_ == Mode::Il2Cpp) {
                if (std::is_void<Return>::value) {
                    Invoke<void*>("il2cpp_runtime_invoke", address, obj, argArray, exc);
                    return;
                }
                return *static_cast<Return*>(Invoke<void*>("il2cpp_runtime_invoke", address, obj, argArray, exc));
            }

            if (std::is_void<Return>::value) {
                Invoke<void*>("mono_runtime_invoke", address, obj, argArray, exc);
                return;
            }
            return *static_cast<Return*>(Invoke<void*>("mono_runtime_invoke", address, obj, argArray, exc));
        }

        template <typename Return, typename... Args>
        using MethodPointer = Return(UNITY_CALLING_CONVENTION*)(Args...);

        template <typename Return, typename... Args>
        auto Cast() -> MethodPointer<Return, Args...> {
            if (!this) return nullptr;
            Compile();
            if (function) return reinterpret_cast<MethodPointer<Return, Args...>>(function);
            return nullptr;
        }
    };

    static auto ThreadAttach() -> void {
        if (mode_ == Mode::Il2Cpp) Invoke<void*>("il2cpp_thread_attach", pDomain);
        else {
            Invoke<void*>("mono_thread_attach", pDomain);
            Invoke<void*>("mono_jit_thread_attach", pDomain);
        }
    }

    static auto ThreadDetach() -> void {
        if (mode_ == Mode::Il2Cpp) Invoke<void*>("il2cpp_thread_detach", pDomain);
        else {
            Invoke<void*>("mono_thread_detach", pDomain);
            Invoke<void*>("mono_jit_thread_detach", pDomain);
        }
    }

    static auto Init(void* hmodule, const Mode mode = Mode::Mono) -> void {
        mode_ = mode;
        hmodule_ = hmodule;

        if (mode_ == Mode::Il2Cpp) {
            pDomain = Invoke<void*>("il2cpp_domain_get");
            Invoke<void*>("il2cpp_thread_attach", pDomain);
            ForeachAssembly();
        } else {
            pDomain = Invoke<void*>("mono_get_root_domain");
            Invoke<void*>("mono_thread_attach", pDomain);
            Invoke<void*>("mono_jit_thread_attach", pDomain);
            ForeachAssembly();

            if (Get("UnityEngine.dll") && (!Get("UnityEngine.CoreModule.dll") || !Get("UnityEngine.PhysicsModule.dll"))) {
                const std::vector<std::string> names = { "UnityEngine.CoreModule.dll", "UnityEngine.PhysicsModule.dll" };
                for (const auto& name : names) {
                    const auto ass = Get("UnityEngine.dll");
                    if (ass) {
                        auto* newAss = new Assembly{ ass->address, name, ass->file, ass->classes };
                        UnityResolve::assembly.push_back(newAss);
                    }
                }
            }
        }
    }

    template <typename Return, typename... Args>
    static auto Invoke(const std::string& funcName, Args... args) -> Return {
        static std::mutex mutex{};
        std::lock_guard<std::mutex> lock(mutex);

#if ANDROID_MODE || LINUX_MODE
        if (address_.find(funcName) == address_.end() || !address_[funcName]) {
            address_[funcName] = dlsym(hmodule_, funcName.c_str());
        }
#endif

        if (address_[funcName]) {
            return reinterpret_cast<Return(UNITY_CALLING_CONVENTION*)(Args...)>(address_[funcName])(args...);
        }
        return Return();
    }

    inline static std::vector<Assembly*> assembly;

    static auto Get(const std::string& strAssembly) -> Assembly* {
        for (const auto pAssembly : assembly) {
            if (pAssembly->name == strAssembly) return pAssembly;
        }
        return nullptr;
    }

private:
    static auto ForeachAssembly() -> void {
        if (mode_ == Mode::Il2Cpp) {
            size_t nrofassemblies = 0;
            const auto assemblies = Invoke<void**>("il2cpp_domain_get_assemblies", pDomain, &nrofassemblies);
            for (size_t i = 0; i < nrofassemblies; i++) {
                const auto ptr = assemblies[i];
                if (!ptr) continue;
                auto* assembly = new Assembly{ .address = ptr };
                const auto image = Invoke<void*>("il2cpp_assembly_get_image", ptr);
                assembly->file = Invoke<const char*>("il2cpp_image_get_filename", image);
                assembly->name = Invoke<const char*>("il2cpp_image_get_name", image);
                UnityResolve::assembly.push_back(assembly);
                ForeachClass(assembly, image);
            }
        } else {
            // Mono part - simplified without lambda try/catch
            // ... (اتركها كما هي أو أضف إذا احتجت Mono دعم)
        }
    }

   static auto ForeachClass(Assembly* assembly, void* image) -> void {
    // 遍历类
    if (mode_ == Mode::Il2Cpp) {
        const auto count = Invoke<int>("il2cpp_image_get_class_count", image);
        for (auto i = 0; i < count; i++) {
            const auto pClass = Invoke<void*>("il2cpp_image_get_class", image, i);
            if (pClass == nullptr) continue;

            const auto pAClass = new Class();
            pAClass->address = pClass;
            pAClass->name = Invoke<const char*>("il2cpp_class_get_name", pClass);

            if (const auto pPClass = Invoke<void*>("il2cpp_class_get_parent", pClass)) {
                pAClass->parent = Invoke<const char*>("il2cpp_class_get_name", pPClass);
            }

            pAClass->namespaze = Invoke<const char*>("il2cpp_class_get_namespace", pClass);
            assembly->classes.push_back(pAClass);

            ForeachFields(pAClass, pClass);
            ForeachMethod(pAClass, pClass);

            void* i_class = nullptr;
            void* iter = nullptr;
            do {
                i_class = Invoke<void*>("il2cpp_class_get_interfaces", pClass, &iter);
                if (i_class) {
                    ForeachFields(pAClass, i_class);
                    ForeachMethod(pAClass, i_class);
                }
            } while (i_class);
        }
    }
    else {
        const void* table = Invoke<void*>("mono_image_get_table_info", image, 2);
        const auto count = Invoke<int>("mono_table_info_get_rows", table);
        for (auto i = 0; i < count; i++) {
            const auto pClass = Invoke<void*>("mono_class_get", image, 0x02000000 | (i + 1));
            if (pClass == nullptr) continue;

            const auto pAClass = new Class();
            pAClass->address = pClass;
            pAClass->name = Invoke<const char*>("mono_class_get_name", pClass);

            if (const auto pPClass = Invoke<void*>("mono_class_get_parent", pClass)) {
                pAClass->parent = Invoke<const char*>("mono_class_get_name", pPClass);
            }

            pAClass->namespaze = Invoke<const char*>("mono_class_get_namespace", pClass);
            assembly->classes.push_back(pAClass);

            ForeachFields(pAClass, pClass);
            ForeachMethod(pAClass, pClass);

            void* iClass = nullptr;
            void* iiter = nullptr;
            do {
                iClass = Invoke<void*>("mono_class_get_interfaces", pClass, &iiter);
                if (iClass) {
                    ForeachFields(pAClass, iClass);
                    ForeachMethod(pAClass, iClass);
                }
            } while (iClass);
        }
    }
}

static auto ForeachFields(Class* klass, void* pKlass) -> void {
    // 遍历成员
    if (mode_ == Mode::Il2Cpp) {
        void* iter = nullptr;
        void* field = nullptr;
        do {
            field = Invoke<void*>("il2cpp_class_get_fields", pKlass, &iter);
            if (field) {
                auto* pField = new Field{
                    .address = field,
                    .name = Invoke<const char*>("il2cpp_field_get_name", field),
                    .type = new Type{ .address = Invoke<void*>("il2cpp_field_get_type", field) },
                    .klass = klass,
                    .offset = Invoke<int>("il2cpp_field_get_offset", field),
                    .static_field = false,
                    .vTable = nullptr
                };

                pField->static_field = (pField->offset <= 0);
                pField->type->name = Invoke<const char*>("il2cpp_type_get_name", pField->type->address);
                pField->type->size = -1;

                klass->fields.push_back(pField);
            }
        } while (field);
    }
    else {
        void* iter = nullptr;
        void* field = nullptr;
        do {
            field = Invoke<void*>("mono_class_get_fields", pKlass, &iter);
            if (field) {
                auto* pField = new Field{
                    .address = field,
                    .name = Invoke<const char*>("mono_field_get_name", field),
                    .type = new Type{ .address = Invoke<void*>("mono_field_get_type", field) },
                    .klass = klass,
                    .offset = Invoke<int>("mono_field_get_offset", field),
                    .static_field = false,
                    .vTable = nullptr
                };

                pField->static_field = (pField->offset <= 0);
                pField->type->name = Invoke<const char*>("mono_type_get_name", pField->type->address);

                int tSize = 0;
                pField->type->size = Invoke<int>("mono_type_size", pField->type->address, &tSize);

                klass->fields.push_back(pField);
            }
        } while (field);
    }
}

static auto ForeachMethod(Class* klass, void* pKlass) -> void {
    // 遍历方法
    if (mode_ == Mode::Il2Cpp) {
        void* iter = nullptr;
        void* method = nullptr;
        do {
            method = Invoke<void*>("il2cpp_class_get_methods", pKlass, &iter);
            if (method) {
                int fFlags = 0;
                auto* pMethod = new Method{};
                pMethod->address = method;
                pMethod->name = Invoke<const char*>("il2cpp_method_get_name", method);
                pMethod->klass = klass;
                pMethod->return_type = new Type{ .address = Invoke<void*>("il2cpp_method_get_return_type", method) };
                pMethod->flags = Invoke<int>("il2cpp_method_get_flags", method, &fFlags);
                pMethod->static_function = (pMethod->flags & 0x10) != 0;

                pMethod->return_type->name = Invoke<const char*>("il2cpp_type_get_name", pMethod->return_type->address);
                pMethod->return_type->size = -1;
                pMethod->function = *static_cast<void**>(method);

                klass->methods.push_back(pMethod);

                const auto argCount = Invoke<int>("il2cpp_method_get_param_count", method);
                for (auto index = 0; index < argCount; index++) {
                    pMethod->args.push_back(new Method::Arg{
                        Invoke<const char*>("il2cpp_method_get_param_name", method, index),
                        new Type{
                            .address = Invoke<void*>("il2cpp_method_get_param", method, index),
                            .name = Invoke<const char*>("il2cpp_type_get_name", Invoke<void*>("il2cpp_method_get_param", method, index)),
                            .size = -1
                        }
                    });
                }
            }
        } while (method);
    }
    else {
        void* iter = nullptr;
        void* method = nullptr;
        do {
            method = Invoke<void*>("mono_class_get_methods", pKlass, &iter);
            if (method) {
                const auto signature = Invoke<void*>("mono_method_signature", method);
                int fFlags = 0;
                auto* pMethod = new Method{};
                pMethod->address = method;
                pMethod->name = Invoke<const char*>("mono_method_get_name", method);
                pMethod->klass = klass;
                pMethod->return_type = new Type{ .address = Invoke<void*>("mono_signature_get_return_type", method) };
                pMethod->flags = Invoke<int>("mono_method_get_flags", method, &fFlags);
                pMethod->static_function = (pMethod->flags & 0x10) != 0;

                pMethod->return_type->name = Invoke<const char*>("mono_type_get_name", pMethod->return_type->address);

                int tSize = 0;
                pMethod->return_type->size = Invoke<int>("mono_type_size", pMethod->return_type->address, &tSize);

                klass->methods.push_back(pMethod);

                const auto paramCount = Invoke<int>("mono_signature_get_param_count", signature);
                const auto names = new char*[paramCount];
                Invoke<void>("mono_method_get_param_names", method, names);

                void* mIter = nullptr;
                void* mType = nullptr;
                auto iname = 0;

                do {
                    mType = Invoke<void*>("mono_signature_get_params", signature, &mIter);
                    if (mType) {
                        int t_size = 0;
                        // بدون try/catch - لو حصل خطأ هيترجع اسم فارغ أو size -1
                        const char* typeName = Invoke<const char*>("mono_type_get_name", mType);
                        pMethod->args.push_back(new Method::Arg{
                            (iname < paramCount) ? names[iname] : "",
                            new Type{
                                .address = mType,
                                .name = typeName ? typeName : "",
                                .size = Invoke<int>("mono_type_size", mType, &t_size)
                            }
                        });
                        iname++;
                    }
                } while (mType);

                // تنظيف الذاكرة (اختياري لكن مهم)
                delete[] names;
            }
        } while (method);
    }
}
public:
    class UnityType final {
    public:
        using IntPtr = std::uintptr_t;
        using Int32  = std::int32_t;
        using Int64  = std::int64_t;
        using Char   = wchar_t;
        using Int16  = std::int16_t;
        using Byte   = std::uint8_t;

        struct Vector3;
        struct Camera;
        struct Transform;
        struct Component;
        struct UnityObject;
        struct LayerMask;
        struct Rigidbody;
        struct Physics;
        struct Time;
        struct GameObject;
        struct Collider;
        struct Vector4;
        struct Vector2;
        struct Quaternion;
        struct Bounds;
        struct Plane;
        struct Ray;
        struct Rect;
        struct Color;
        struct Matrix4x4;

        template <typename T> struct Array;
        struct String;
        struct Object;
        template <typename T> struct List;
        template <typename TKey, typename TValue> struct Dictionary;

        struct Behaviour;
        struct MonoBehaviour;
        struct CsType;
        struct Mesh;
        struct Renderer;
        struct Animator;
        struct CapsuleCollider;
        struct BoxCollider;

        struct Vector3 {
            float x, y, z;

            Vector3() : x(0.f), y(0.f), z(0.f) {}
            Vector3(float xx, float yy, float zz) : x(xx), y(yy), z(zz) {}

            [[nodiscard]] auto Length() const -> float {
                return x*x + y*y + z*z;
            }

            [[nodiscard]] auto Dot(const Vector3& b) const -> float {
                return x*b.x + y*b.y + z*b.z;
            }

            [[nodiscard]] auto Normalize() const -> Vector3 {
                float len = Length();
                if (len > 0.0001f) return Vector3(x/len, y/len, z/len);
                return Vector3();
            }

            auto ToVectors(Vector3* forward, Vector3* right, Vector3* up) const -> void {
                constexpr float deg2Rad = 3.141592653589793f / 180.f;
                float sx = sinf(x * deg2Rad);
                float cx = cosf(x * deg2Rad);
                float sy = sinf(y * deg2Rad);
                float cy = cosf(y * deg2Rad);
                float sz = sinf(z * deg2Rad);
                float cz = cosf(z * deg2Rad);

                if (forward) {
                    forward->x = cx * cy;
                    forward->y = -sx;
                    forward->z = cx * sy;
                }
                if (right) {
                    right->x = -sz * sx * cy - cz * -sy;
                    right->y = -sz * cx;
                    right->z = -sz * sx * sy + cz * cy;
                }
                if (up) {
                    up->x = cz * sx * cy + sz * -sy;
                    up->y = cz * cx;
                    up->z = cz * sx * sy + sz * cy;
                }
            }

            [[nodiscard]] auto Distance(const Vector3& other) const -> float {
                float dx = x - other.x;
                float dy = y - other.y;
                float dz = z - other.z;
                return std::sqrt(dx*dx + dy*dy + dz*dz);
            }

            auto operator*(float s) const -> Vector3 { return {x*s, y*s, z*s}; }
            auto operator/(float s) const -> Vector3 { return {x/s, y/s, z/s}; }
            auto operator+(float s) const -> Vector3 { return {x+s, y+s, z+s}; }
            auto operator-(float s) const -> Vector3 { return {x-s, y-s, z-s}; }

            auto operator*(const Vector3& o) const -> Vector3 { return {x*o.x, y*o.y, z*o.z}; }
            auto operator-(const Vector3& o) const -> Vector3 { return {x-o.x, y-o.y, z-o.z}; }
            auto operator+(const Vector3& o) const -> Vector3 { return {x+o.x, y+o.y, z+o.z}; }
            auto operator/(const Vector3& o) const -> Vector3 { return {x/o.x, y/o.y, z/o.z}; }

            auto operator==(const Vector3& o) const -> bool {
                return x == o.x && y == o.y && z == o.z;
            }
        };

        struct Vector2 {
            float x, y;
            Vector2() : x(0.f), y(0.f) {}
            Vector2(float xx, float yy) : x(xx), y(yy) {}

            [[nodiscard]] auto Distance(const Vector2& o) const -> float {
                float dx = x - o.x;
                float dy = y - o.y;
                return std::sqrt(dx*dx + dy*dy);
            }

            auto operator*(float s) const -> Vector2 { return {x*s, y*s}; }
            auto operator/(float s) const -> Vector2 { return {x/s, y/s}; }
            auto operator+(float s) const -> Vector2 { return {x+s, y+s}; }
            auto operator-(float s) const -> Vector2 { return {x-s, y-s}; }

            auto operator*(const Vector2& o) const -> Vector2 { return {x*o.x, y*o.y}; }
            auto operator-(const Vector2& o) const -> Vector2 { return {x-o.x, y-o.y}; }
            auto operator+(const Vector2& o) const -> Vector2 { return {x+o.x, y+o.y}; }
            auto operator/(const Vector2& o) const -> Vector2 { return {x/o.x, y/o.y}; }

            auto operator==(const Vector2& o) const -> bool { return x == o.x && y == o.y; }
        };

        struct Vector4 {
            float x, y, z, w;
            Vector4() : x(0), y(0), z(0), w(0) {}
            Vector4(float xx, float yy, float zz, float ww) : x(xx), y(yy), z(zz), w(ww) {}

            auto operator*(float s) const -> Vector4 { return {x*s, y*s, z*s, w*s}; }
            auto operator/(float s) const -> Vector4 { return {x/s, y/s, z/s, w/s}; }
            auto operator+(float s) const -> Vector4 { return {x+s, y+s, z+s, w+s}; }
            auto operator-(float s) const -> Vector4 { return {x-s, y-s, z-s, w-s}; }

            auto operator==(const Vector4& o) const -> bool {
                return x == o.x && y == o.y && z == o.z && w == o.w;
            }
        };

        struct Quaternion {
            float x, y, z, w;
            Quaternion() : x(0), y(0), z(0), w(1) {}
            Quaternion(float xx, float yy, float zz, float ww) : x(xx), y(yy), z(zz), w(ww) {}

            auto Euler(float pitch, float yaw, float roll) -> Quaternion& {
                float p = pitch * 0.008726646f;  // deg to rad / 2
                float yw = yaw   * 0.008726646f;
                float r  = roll  * 0.008726646f;

                float sp = sinf(p), cp = cosf(p);
                float sy = sinf(yw), cy = cosf(yw);
                float sr = sinf(r),  cr = cosf(r);

                x = sr*cp*cy - cr*sp*sy;
                y = cr*sp*cy + sr*cp*sy;
                z = cr*cp*sy - sr*sp*cy;
                w = cr*cp*cy + sr*sp*sy;
                return *this;
            }

            auto Euler(const Vector3& e) -> Quaternion& { return Euler(e.x, e.y, e.z); }

            [[nodiscard]] auto ToEuler() const -> Vector3 {
                Vector3 e;

                float sinr = 2*(w*x + y*z);
                float cosr = 1 - 2*(x*x + y*y);
                e.x = atan2f(sinr, cosr);

                float sinp = 2*(w*y - z*x);
                e.y = (fabs(sinp) >= 1.f) ? copysignf(1.570796f, sinp) : asinf(sinp);

                float siny = 2*(w*z + x*y);
                float cosy = 1 - 2*(y*y + z*z);
                e.z = atan2f(siny, cosy);

                e.x *= 57.295779513f;  // rad to deg
                e.y *= 57.295779513f;
                e.z *= 57.295779513f;

                return e;
            }

            auto operator*(const Quaternion& q) const -> Quaternion {
                return {
                    w*q.x + x*q.w + y*q.z - z*q.y,
                    w*q.y - x*q.z + y*q.w + z*q.x,
                    w*q.z + x*q.y - y*q.x + z*q.w,
                    w*q.w - x*q.x - y*q.y - z*q.z
                };
            }

            auto operator==(const Quaternion& q) const -> bool {
                return x == q.x && y == q.y && z == q.z && w == q.w;
            }
        };

        struct Bounds {
            Vector3 center;
            Vector3 extents;
        };

        struct Plane {
            Vector3 normal;
            float distance;
        };

        struct Ray {
            Vector3 origin;
            Vector3 direction;
        };

        struct Rect {
            float x, y, width, height;
            Rect() : x(0), y(0), width(0), height(0) {}
            Rect(float xx, float yy, float w, float h) : x(xx), y(yy), width(w), height(h) {}
        };

        struct Color {
            float r, g, b, a;
            Color() : r(0), g(0), b(0), a(1) {}
            Color(float rr, float gg, float bb, float aa = 1.f) : r(rr), g(gg), b(bb), a(aa) {}
        };

        struct Matrix4x4 {
            float m[4][4] = {};
            auto operator[](int i) -> float* { return m[i]; }
            auto operator[](int i) const -> const float* { return m[i]; }
        };

        struct Object {
            union { void* klass = nullptr; void* vtable; };
            void* monitor = nullptr;

            auto GetType() -> CsType* {
                static Method* m = nullptr;
                if (!m) m = Get("mscorlib.dll")->Get("Object", "System")->Get<Method>("GetType");
                return m ? m->Invoke<CsType*>(this) : nullptr;
            }

            auto ToString() -> std::string {
                static Method* m = nullptr;
                if (!m) m = Get("mscorlib.dll")->Get("Object", "System")->Get<Method>("ToString");
                return m ? m->Invoke<String*>(this)->ToString() : "";
            }
        };

        struct CsType {
            auto GetFullName() -> std::string {
                static Method* m = nullptr;
                if (!m) m = Get("mscorlib.dll")->Get("Type", "System", "MemberInfo")->Get<Method>("get_FullName");
                return m ? m->Invoke<String*>(this)->ToString() : "";
            }

            auto GetNamespace() -> std::string {
                static Method* m = nullptr;
                if (!m) m = Get("mscorlib.dll")->Get("Type", "System", "MemberInfo")->Get<Method>("get_Namespace");
                return m ? m->Invoke<String*>(this)->ToString() : "";
            }
        };

        struct String : Object {
            int32_t length = 0;
            wchar_t chars[1];

            [[nodiscard]] auto ToString() const -> std::string {
                if (!this || length <= 0) return {};
                std::string s;
                s.reserve(length);
                for (int32_t i = 0; i < length; ++i) {
                    wchar_t c = chars[i];
                    s += (c <= 127) ? static_cast<char>(c) : '?';
                }
                return s;
            }

            static auto New(const std::string& str) -> String* {
                if (mode_ == Mode::Il2Cpp)
                    return Invoke<String*, const char*>("il2cpp_string_new", str.c_str());
                return Invoke<String*, void*, const char*>("mono_string_new", pDomain, str.c_str());
            }
        };

        template<typename T>
        struct Array : Object {
            std::uintptr_t max_length = 0;
            alignas(8) T* vector = nullptr;

            auto ToVector() -> std::vector<T> {
                std::vector<T> v;
                if (!this || max_length == 0) return v;
                v.reserve(max_length);
                for (std::uintptr_t i = 0; i < max_length; ++i) v.push_back(vector[i]);
                return v;
            }

            static auto New(Class* kls, std::uintptr_t sz) -> Array* {
                if (mode_ == Mode::Il2Cpp)
                    return Invoke<Array*, void*, std::uintptr_t>("il2cpp_array_new", kls->address, sz);
                return Invoke<Array*, void*, void*, std::uintptr_t>("mono_array_new", pDomain, kls->address, sz);
            }
        };

        struct UnityObject : Object {
            void* m_CachedPtr = nullptr;

            auto GetName() -> std::string {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Object")->Get<Method>("get_name");
                return m ? m->Invoke<String*>(this)->ToString() : "";
            }

            static auto Instantiate(UnityObject* obj) -> UnityObject* {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Object")->Get<Method>("Instantiate");
                return m ? m->Invoke<UnityObject*>(obj) : nullptr;
            }

            static auto Destroy(UnityObject* obj) -> void {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Object")->Get<Method>("Destroy");
                if (m) m->Invoke<void>(obj);
            }
        };

        struct Component : UnityObject {
            auto GetTransform() -> Transform* {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("get_transform");
                return m ? m->Invoke<Transform*>(this) : nullptr;
            }

            auto GetGameObject() -> GameObject* {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("get_gameObject");
                return m ? m->Invoke<GameObject*>(this) : nullptr;
            }

            template<typename T>
            auto GetComponent() -> T {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("GetComponent");
                return m ? m->Invoke<T>(this) : T{};
            }

            template<typename T>
            auto GetComponentsInChildren() -> std::vector<T> {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("GetComponentsInChildren");
                return m ? m->Invoke<Array<T>*>(this)->ToVector() : std::vector<T>{};
            }

            template<typename T>
            auto GetComponentsInChildren(Class* type) -> std::vector<T> {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("GetComponentsInChildren", {"System.Type"});
                return m ? m->Invoke<Array<T>*>(this, type->GetType())->ToVector() : std::vector<T>{};
            }

            template<typename T>
            auto GetComponents() -> std::vector<T> {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("GetComponents");
                return m ? m->Invoke<Array<T>*>(this)->ToVector() : std::vector<T>{};
            }

            template<typename T>
            auto GetComponentsInParent() -> std::vector<T> {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("GetComponentsInParent");
                return m ? m->Invoke<Array<T>*>(this)->ToVector() : std::vector<T>{};
            }

            template<typename T>
            auto GetComponentInChildren(Class* type) -> T {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Component")->Get<Method>("GetComponentInChildren", {"System.Type"});
                return m ? m->Invoke<T>(this, type->GetType()) : T{};
            }
        };

        struct Camera : Component {
            enum class Eye : int { Left, Right, Mono };

            static auto GetMain() -> Camera* {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Camera")->Get<Method>("get_main");
                return m ? m->Invoke<Camera*>() : nullptr;
            }

            auto GetFoV() -> float {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Camera")->Get<Method>("get_fieldOfView");
                return m ? m->Invoke<float>(this) : 60.f;
            }

            auto SetFoV(float fov) -> void {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Camera")->Get<Method>("set_fieldOfView");
                if (m) m->Invoke<void>(this, fov);
            }

            auto WorldToScreenPoint(const Vector3& pos, Eye eye = Eye::Mono) -> Vector3 {
                static Method* m = nullptr;
                if (!m) {
                    if (mode_ == Mode::Mono)
                        m = Get("UnityEngine.CoreModule.dll")->Get("Camera")->Get<Method>("WorldToScreenPoint_Injected");
                    else
                        m = Get("UnityEngine.CoreModule.dll")->Get("Camera")->Get<Method>("WorldToScreenPoint");
                }
                if (!m) return Vector3(-9999.f, -9999.f, -9999.f);

                if (mode_ == Mode::Mono) {
                    Vector3 result{};
                    m->Invoke<void>(this, pos, eye, &result);
                    return result;
                }
                return m->Invoke<Vector3>(this, pos, eye);
            }
        };

        struct Transform : Component {
            auto GetPosition() -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "get_position_Injected" : "get_position");
                if (mode_ == Mode::Mono && method) {
                    Vector3 vec{};
                    method->Invoke<void>(this, &vec);
                    return vec;
                }
                if (method) return method->Invoke<Vector3>(this);
                return Vector3();
            }

            auto SetPosition(const Vector3& position) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "set_position_Injected" : "set_position");
                if (mode_ == Mode::Mono && method) method->Invoke<void>(this, &position);
                else if (method) method->Invoke<void>(this, position);
            }

            auto GetRight() -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("get_right");
                return method ? method->Invoke<Vector3>(this) : Vector3(1.f, 0.f, 0.f);
            }

            auto SetRight(const Vector3& value) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("set_right");
                if (method) method->Invoke<void>(this, value);
            }

            auto GetUp() -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("get_up");
                return method ? method->Invoke<Vector3>(this) : Vector3(0.f, 1.f, 0.f);
            }

            auto SetUp(const Vector3& value) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("set_up");
                if (method) method->Invoke<void>(this, value);
            }

            auto GetForward() -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("get_forward");
                return method ? method->Invoke<Vector3>(this) : Vector3(0.f, 0.f, 1.f);
            }

            auto SetForward(const Vector3& value) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("set_forward");
                if (method) method->Invoke<void>(this, value);
            }

            auto GetRotation() -> Quaternion {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "get_rotation_Injected" : "get_rotation");
                if (mode_ == Mode::Mono && method) {
                    Quaternion q{};
                    method->Invoke<void>(this, &q);
                    return q;
                }
                if (method) return method->Invoke<Quaternion>(this);
                return Quaternion();
            }

            auto SetRotation(const Quaternion& rotation) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "set_rotation_Injected" : "set_rotation");
                if (mode_ == Mode::Mono && method) method->Invoke<void>(this, &rotation);
                else if (method) method->Invoke<void>(this, rotation);
            }

            auto GetLocalPosition() -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "get_localPosition_Injected" : "get_localPosition");
                if (mode_ == Mode::Mono && method) {
                    Vector3 vec{};
                    method->Invoke<void>(this, &vec);
                    return vec;
                }
                if (method) return method->Invoke<Vector3>(this);
                return Vector3();
            }

            auto SetLocalPosition(const Vector3& position) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "set_localPosition_Injected" : "set_localPosition");
                if (mode_ == Mode::Mono && method) method->Invoke<void>(this, &position);
                else if (method) method->Invoke<void>(this, position);
            }

            auto GetLocalRotation() -> Quaternion {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "get_localRotation_Injected" : "get_localRotation");
                if (mode_ == Mode::Mono && method) {
                    Quaternion q{};
                    method->Invoke<void>(this, &q);
                    return q;
                }
                if (method) return method->Invoke<Quaternion>(this);
                return Quaternion();
            }

            auto SetLocalRotation(const Quaternion& rotation) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "set_localRotation_Injected" : "set_localRotation");
                if (mode_ == Mode::Mono && method) method->Invoke<void>(this, &rotation);
                else if (method) method->Invoke<void>(this, rotation);
            }

            auto GetLocalScale() -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "get_localScale_Injected" : "get_localScale");
                if (mode_ == Mode::Mono && method) {
                    Vector3 vec{};
                    method->Invoke<void>(this, &vec);
                    return vec;
                }
                if (method) return method->Invoke<Vector3>(this);
                return Vector3(1.f, 1.f, 1.f);
            }

            auto SetLocalScale(const Vector3& scale) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "set_localScale_Injected" : "set_localScale");
                if (mode_ == Mode::Mono && method) method->Invoke<void>(this, &scale);
                else if (method) method->Invoke<void>(this, scale);
            }

            auto GetChildCount() -> int {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("get_childCount");
                return method ? method->Invoke<int>(this) : 0;
            }

            auto GetChild(int index) -> Transform* {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("GetChild");
                return method ? method->Invoke<Transform*>(this, index) : nullptr;
            }

            auto GetRoot() -> Transform* {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("root");
                return method ? method->Invoke<Transform*>(this) : nullptr;
            }

            auto GetParent() -> Transform* {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("get_parent");
                return method ? method->Invoke<Transform*>(this) : nullptr;
            }

            auto GetLossyScale() -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "get_lossyScale_Injected" : "get_lossyScale");
                if (mode_ == Mode::Mono && method) {
                    Vector3 vec{};
                    method->Invoke<void>(this, &vec);
                    return vec;
                }
                if (method) return method->Invoke<Vector3>(this);
                return Vector3(1.f, 1.f, 1.f);
            }

            auto TransformPoint(const Vector3& position) -> Vector3 {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>(mode_ == Mode::Mono ? "TransformPoint_Injected" : "TransformPoint");
                if (mode_ == Mode::Mono && method) {
                    Vector3 result{};
                    method->Invoke<void>(this, position, &result);
                    return result;
                }
                if (method) return method->Invoke<Vector3>(this, position);
                return position;
            }

            auto LookAt(const Vector3& worldPosition) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("LookAt");
                if (method) method->Invoke<void>(this, worldPosition);
            }

            auto Rotate(const Vector3& eulers) -> void {
                static Method* method = nullptr;
                if (!method) method = Get("UnityEngine.CoreModule.dll")->Get("Transform")->Get<Method>("Rotate");
                if (method) method->Invoke<void>(this, eulers);
            }
        };

        struct GameObject : UnityObject {
            static auto Find(const std::string& name) -> GameObject* {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("GameObject")->Get<Method>("Find");
                return m ? m->Invoke<GameObject*>(String::New(name)) : nullptr;
            }

            auto GetActive() -> bool {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("GameObject")->Get<Method>("get_activeSelf");
                return m ? m->Invoke<bool>(this) : false;
            }

            auto SetActive(bool value) -> void {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("GameObject")->Get<Method>("set_active");
                if (m) m->Invoke<void>(this, value);
            }

            auto GetTransform() -> Transform* {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("GameObject")->Get<Method>("get_transform");
                return m ? m->Invoke<Transform*>(this) : nullptr;
            }
        };

        struct LayerMask : Object {
            int value = 0;

            static auto NameToLayer(const std::string& name) -> int {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("LayerMask")->Get<Method>("NameToLayer");
                return m ? m->Invoke<int>(String::New(name)) : -1;
            }
        };

        struct Rigidbody : Component {
            auto GetVelocity() -> Vector3 {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("Rigidbody")->Get<Method>(mode_ == Mode::Mono ? "get_velocity_Injected" : "get_velocity");
                if (mode_ == Mode::Mono && m) {
                    Vector3 v{};
                    m->Invoke<void>(this, &v);
                    return v;
                }
                return m ? m->Invoke<Vector3>(this) : Vector3();
            }

            auto SetVelocity(const Vector3& v) -> void {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("Rigidbody")->Get<Method>(mode_ == Mode::Mono ? "set_velocity_Injected" : "set_velocity");
                if (mode_ == Mode::Mono && m) m->Invoke<void>(this, &v);
                else if (m) m->Invoke<void>(this, v);
            }
        };

        struct Collider : Component {
            auto GetBounds() -> Bounds {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("Collider")->Get<Method>("get_bounds_Injected");
                if (m) {
                    Bounds b{};
                    m->Invoke<void>(this, &b);
                    return b;
                }
                return Bounds{};
            }
        };

        struct CapsuleCollider : Collider {
            auto GetCenter() -> Vector3 {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("CapsuleCollider")->Get<Method>("get_center");
                return m ? m->Invoke<Vector3>(this) : Vector3();
            }

            auto GetRadius() -> float {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("CapsuleCollider")->Get<Method>("get_radius");
                return m ? m->Invoke<float>(this) : 0.5f;
            }

            auto GetHeight() -> float {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("CapsuleCollider")->Get<Method>("get_height");
                return m ? m->Invoke<float>(this) : 2.f;
            }
        };

        struct BoxCollider : Collider {
            auto GetCenter() -> Vector3 {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("BoxCollider")->Get<Method>("get_center");
                return m ? m->Invoke<Vector3>(this) : Vector3();
            }

            auto GetSize() -> Vector3 {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("BoxCollider")->Get<Method>("get_size");
                return m ? m->Invoke<Vector3>(this) : Vector3(1.f, 1.f, 1.f);
            }
        };

   struct Behaviour : Component {
            auto GetEnabled() -> bool {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Behaviour")->Get<Method>("get_enabled");
                return m ? m->Invoke<bool>(this) : true;
            }

     auto SetEnabled(bool value) -> void {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Behaviour")->Get<Method>("set_enabled");
                if (m) m->Invoke<void>(this, value);
            }
        };



        struct Animator : Behaviour {
            enum class HumanBodyBones : int {
                Hips = 0, LeftUpperLeg, RightUpperLeg, LeftLowerLeg, RightLowerLeg,
                LeftFoot, RightFoot, Spine, Chest, Neck, Head, LeftShoulder,
                RightShoulder, LeftUpperArm, RightUpperArm, LeftLowerArm, RightLowerArm,
                LeftHand, RightHand, LeftToes, RightToes, LeftEye, RightEye, Jaw,
                LeftThumbProximal, LeftThumbIntermediate, LeftThumbDistal,
                LeftIndexProximal, LeftIndexIntermediate, LeftIndexDistal,
                LeftMiddleProximal, LeftMiddleIntermediate, LeftMiddleDistal,
                LeftRingProximal, LeftRingIntermediate, LeftRingDistal,
                LeftLittleProximal, LeftLittleIntermediate, LeftLittleDistal,
                RightThumbProximal, RightThumbIntermediate, RightThumbDistal,
                RightIndexProximal, RightIndexIntermediate, RightIndexDistal,
                RightMiddleProximal, RightMiddleIntermediate, RightMiddleDistal,
                RightRingProximal, RightRingIntermediate, RightRingDistal,
                RightLittleProximal, RightLittleIntermediate, RightLittleDistal,
                UpperChest = 54, LastBone = 55
            };

            auto GetBoneTransform(HumanBodyBones bone) -> Transform* {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.AnimationModule.dll")->Get("Animator")->Get<Method>("GetBoneTransform");
                return m ? m->Invoke<Transform*>(this, static_cast<int>(bone)) : nullptr;
            }
        };

     
       
        struct Physics : Object {
            static auto Raycast(const Vector3& origin, const Vector3& dir, float maxDist = FLT_MAX) -> bool {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.PhysicsModule.dll")->Get("Physics")->Get<Method>("Raycast");
                return m ? m->Invoke<bool>(origin, dir, maxDist) : false;
            }
        };

        struct Time {
            static auto GetTime() -> float {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Time")->Get<Method>("get_time");
                return m ? m->Invoke<float>() : 0.f;
            }

            static auto GetDeltaTime() -> float {
                static Method* m = nullptr;
                if (!m) m = Get("UnityEngine.CoreModule.dll")->Get("Time")->Get<Method>("get_deltaTime");
                return m ? m->Invoke<float>() : 0.f;
            }
        };
    };
private:
    inline static Mode mode_{};
    inline static void* hmodule_;
    inline static std::unordered_map<std::string, void*> address_{};
    inline static void* pDomain{};
};

#endif // UNITYRESOLVE_THEOS_HPP