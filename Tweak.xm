// Tweak.xm
#include <substrate.h>
#include <dlfcn.h>
#include <math.h>
#include <vector>
#include <unordered_map>
#include <chrono>
#include <string>
#include <map>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include "Header.h"
#include "ICON.h"
#include "MonsterIcon.h"




struct PlayerPositionTrack {
    Vector3 lastPos;
    std::chrono::steady_clock::time_point lastUpdateTime;
    int freezeCounter = 0;
};

static std::unordered_map<void*, PlayerPositionTrack> playerTrackMap;
static int consecutiveFreezeFrames = 0;

// القيم اللي ممكن تعديلها
static const int    FREEZE_THRESHOLD_FRAMES   = 90;     // تقريباً 7–9 ثواني
static const float  POSITION_FREEZE_TOLERANCE = 0.10f;  // حركة أقل من 15 سم = ثبات
static const int    MIN_PLAYERS_TO_CHECK      = 2;      // الحد الأدنى لعدد اللاعبين عشان نطبق المنطق
static const float  FROZEN_RATIO_THRESHOLD    = 0.50f;  // نسبة اللاعبين الثابتين المطلوبة
static const int    CONSECUTIVE_CONFIRM       = 5;      // عدد المرات المتتالية للتأكيد

// Global Declarations
UIScrollView* menuView = NULL;
UIButton* floatingButton = NULL;
UILabel* enemyCountLabel = NULL;
UILabel* updateStatusLabel = NULL;
UILabel* fovStatusLabel = NULL;
UILabel* espLine2StatusLabel = NULL;
UILabel* espBoxStatusLabel = NULL;
UILabel* espIconStatusLabel = NULL;
UILabel* espHealthStatusLabel = NULL;
UILabel* espAllEntityHPStatusLabel = NULL;
UILabel* espMonstersHPStatusLabel = NULL;
UILabel* espMonsterIconStatusLabel = NULL;
UILabel* espAllStatusLabel = NULL;
UIView* generalView = NULL;
UIView* miniMapView = NULL;
UIView* fovView = NULL;
UIView* espSpeedView = NULL;
UIView* titleBar = NULL;
ESPLine2View* espLine2View = NULL;
ESPBoxView* espBoxView = NULL;
ESPIconView* espIconView = NULL;
ESPHealthView* espHealthView = NULL;

static std::map<std::string, UIColor*> heroColorCache;

bool showESPLine2 = false;
bool showESPBoxes = false;
bool showESPIcons = false;
bool showESPHealth = false;
bool showAllEntityHP = false;
bool showMonstersHP = false;
bool showESPMonsterIcons = false;
bool showAllESP = false;
int updateInterval = 2;
CGFloat g_screenScale = 1.0f;
bool g_resolutionSet = false;
void *g_UnityFrameworkHandle = NULL;
uintptr_t baseAddress = 0;
void* BattleManager = NULL;
int updateCounter = 0;
float originalFOV = 0.0f;
float selectedFOV = 30.0f;
const float fovOptions[] = {30.0f, 40.0f, 45.0f, 50.0f, 60.0f, 70.0f, 80.0f, 90.0f};
bool fovModified = false;
Vector3 g_selfPos = Vector3::zero();
std::vector<EnemyData> g_enemies;

// Image Cache
static std::map<std::string, UIImage*> heroIconCache;
static std::map<int, UIImage*> monsterIconCache;

// Dynamic offsets / pointers
size_t off_m_LocalPlayerShow = 0;
size_t off_m_ShowPlayers = 0;
size_t off_m_ShowMonsters = 0;
size_t off_m_bSameCampType = 0;
size_t off_m_bDeath = 0;
size_t off__logicFighter = 0;
size_t off_m_HeroName = 0;
size_t off_m_RoleName = 0;
size_t off_m_Hp = 0;
size_t off_m_HpMax = 0;
size_t off_m_ID = 0;
static Vector3 (*fn_ShowEntity_get_Position)(void *instance) = nullptr;
static void* (*fn_ShowEntity_get_logicFighter)(void *instance) = nullptr;

// IL2CPP Structure Definitions
struct Il2CppString {
    Il2CppObject obj;
    int32_t length;
    wchar_t chars[1];
};

struct Il2CppImage;
struct Il2CppClass;
struct Il2CppType {
    uint32_t attrs;
};
struct Il2CppDomain;
struct Il2CppAssembly;
struct FieldInfo {
    Il2CppType* type;
    uint32_t offset;
};
struct MethodInfo {
    void* methodPointer;
};

// IL2CPP Function Pointers
typedef void (*il2cpp_class_init_ptr)(Il2CppClass*);
typedef Il2CppClass* (*il2cpp_class_from_name_ptr)(const Il2CppImage*, const char*, const char*);
typedef FieldInfo* (*il2cpp_class_get_field_from_name_ptr)(Il2CppClass*, const char*);
typedef const MethodInfo* (*il2cpp_class_get_method_from_name_ptr)(Il2CppClass*, const char*, int);
typedef const Il2CppType* (*il2cpp_class_get_type_ptr)(Il2CppClass*);
typedef Il2CppObject* (*il2cpp_type_get_object_ptr)(const Il2CppType*);
typedef int32_t (*il2cpp_field_get_offset_ptr)(FieldInfo*);
typedef const char* (*il2cpp_class_get_name_ptr)(Il2CppClass*);
typedef const char* (*il2cpp_class_get_namespace_ptr)(Il2CppClass*);
typedef const Il2CppImage* (*il2cpp_assembly_get_image_ptr)(const Il2CppAssembly*);
typedef const char* (*il2cpp_image_get_name_ptr)(const Il2CppImage*);
typedef size_t (*il2cpp_image_get_class_count_ptr)(const Il2CppImage*);
typedef const Il2CppClass* (*il2cpp_image_get_class_ptr)(const Il2CppImage*, size_t);
typedef Il2CppDomain* (*il2cpp_domain_get_ptr)(void);
typedef const Il2CppAssembly** (*il2cpp_domain_get_assemblies_ptr)(const Il2CppDomain*, size_t*);
typedef void* (*il2cpp_class_get_static_field_data_ptr)(Il2CppClass*);
typedef Vector3 (*Camera_WorldToScreenPoint_ptr)(void*, Vector3);
typedef void (*Screen_SetResolution_ptr)(int, int, bool);

// Resolved pointers
il2cpp_class_init_ptr il2cpp_class_init = NULL;
il2cpp_class_from_name_ptr il2cpp_class_from_name = NULL;
il2cpp_class_get_field_from_name_ptr il2cpp_class_get_field_from_name = NULL;
il2cpp_class_get_method_from_name_ptr il2cpp_class_get_method_from_name = NULL;
il2cpp_class_get_type_ptr il2cpp_class_get_type = NULL;
il2cpp_type_get_object_ptr il2cpp_type_get_object = NULL;
il2cpp_field_get_offset_ptr il2cpp_field_get_offset = NULL;
il2cpp_class_get_name_ptr il2cpp_class_get_name = NULL;
il2cpp_class_get_namespace_ptr il2cpp_class_get_namespace = NULL;
il2cpp_assembly_get_image_ptr il2cpp_assembly_get_image = NULL;
il2cpp_image_get_name_ptr il2cpp_image_get_name = NULL;
il2cpp_image_get_class_count_ptr il2cpp_image_get_class_count = NULL;
il2cpp_image_get_class_ptr il2cpp_image_get_class = NULL;
il2cpp_domain_get_ptr il2cpp_domain_get = NULL;
il2cpp_domain_get_assemblies_ptr il2cpp_domain_get_assemblies = NULL;
il2cpp_class_get_static_field_data_ptr il2cpp_class_get_static_field_data = NULL;
Camera_WorldToScreenPoint_ptr Camera_WorldToScreenPoint = NULL;
float (*Camera_get_fieldOfView)(void *camera) = nullptr;
void (*Camera_set_fieldOfView)(void *camera, float value) = nullptr;
Screen_SetResolution_ptr Screen_SetResolution = NULL;

static std::unordered_map<std::string, UIColor*> currentMatchHeroColors;

// ====================== GetHeroColor Function ======================
static UIColor* GetHeroColor(NSString* heroName) {
    if (!heroName || heroName.length == 0)
        return [UIColor whiteColor];

    std::string key = [heroName UTF8String];

    // استرجاع اللون إذا كان موجود مسبقاً في الماتش
    auto it = currentMatchHeroColors.find(key);
    if (it != currentMatchHeroColors.end()) {
        return it->second;
    }

    // جدول ألوان قوي وممنوع الأحمر تماماً
    static const struct { CGFloat h, s, b; } distinctColors[] = {
        {210, 0.95, 0.98}, // أزرق سماوي ناصع
        {195, 0.92, 0.97}, // سماوي فاتح
        {220, 0.88, 0.96}, // أزرق متوسط
        {240, 0.90, 0.97}, // أزرق بنفسجي
        {260, 0.85, 0.95}, // بنفسجي فاتح
        {280, 0.82, 0.96}, // بنفسجي-أزرق
        {165, 0.88, 0.94}, // أخضر سماوي
        {135, 0.90, 0.93}, // أخضر ليموني
        {150, 0.85, 0.92}, // أخضر مائي
        {120, 0.92, 0.90}, // أخضر مشرق
        {90,  0.85, 0.95}, // أصفر-أخضر
        {75,  0.88, 0.96}, // أصفر فاتح آمن
        {60,  0.90, 0.97}, // أصفر مشرق
        {45,  0.75, 0.96}, // برتقالي-أصفر خفيف (بعيد عن الأحمر)
        {300, 0.78, 0.94}, // وردي-بنفسجي فاتح
        {315, 0.70, 0.95}, // وردي ناعم
        {200, 0.91, 0.96}, // أزرق سماوي 2
        {230, 0.87, 0.95}, // أزرق غامق فاتح
        {255, 0.80, 0.94}, // أزرق-بنفسجي
        {180, 0.93, 0.95}, // سماوي نقي
        {105, 0.89, 0.93}, // أخضر-أصفر
        {270, 0.83, 0.96}  // بنفسجي فاتح 2
    };

    // Hash للبطل
    uint64_t hash = 0xCBF29CE484222325ULL;
    for (char c : key) {
        hash ^= (unsigned char)c;
        hash *= 0x100000001B3ULL;
    }

    int count = sizeof(distinctColors) / sizeof(distinctColors[0]);
    int startIdx = hash % count;

    for (int i = 0; i < count; ++i) {
        int idx = (startIdx + i) % count;
        auto col = distinctColors[idx];

        UIColor *candidate = [UIColor colorWithHue:col.h / 360.0f
                                       saturation:col.s
                                       brightness:col.b
                                            alpha:1.0f];

        // ====================== حماية قوية ضد اللون الأحمر ======================
        CGFloat r, g, b, a;
        [candidate getRed:&r green:&g blue:&b alpha:&a];

        // رفض أي لون أحمر
        if (r > 0.65f && g < 0.55f && b < 0.55f) {
            continue;
        }
        
        // رفض أي لون قريب من الأحمر
        if (r > g * 1.3f && r > b * 1.3f && r > 0.55f) {
            continue;
        }

        // فحص إذا اللون مستخدم بالفعل (منع التكرار)
        bool colorUsed = false;
        for (const auto& pair : currentMatchHeroColors) {
            CGFloat r1, g1, b1, a1;
            [pair.second getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
            if (fabs(r1 - r) < 0.07f && fabs(g1 - g) < 0.07f && fabs(b1 - b) < 0.07f) {
                colorUsed = true;
                break;
            }
        }

        if (!colorUsed) {
            currentMatchHeroColors[key] = candidate;
            return candidate;
        }
    }

    // Fallback آمن جداً
    UIColor *safeBlue = [UIColor colorWithHue:210.0/360.0
                                  saturation:0.92
                                  brightness:0.98
                                       alpha:1.0];
   
    currentMatchHeroColors[key] = safeBlue;
    return safeBlue;
}

// Initialize Image Cache
static void InitializeImageCache() {
    static bool cacheInitialized = false;
    if (cacheInitialized) return;
    
// Hero Icons
static std::map<std::string, int> heroIconMap = {
    {"miya", 1}, {"balmond", 2}, {"saber", 3}, {"alice", 4}, {"nana", 5},
    {"tigreal", 6}, {"alucard", 7}, {"karina", 8}, {"akai", 9}, {"franco", 10},
    {"bane", 11}, {"bruno", 12}, {"clint", 13}, {"rafaela", 14}, {"eudora", 15},
    {"zilong", 16}, {"fanny", 17}, {"layla", 18}, {"minotaur", 19}, {"lolita", 20},
    {"hayabusa", 21}, {"freya", 22}, {"gord", 23}, {"natalia", 24}, {"kagura", 25},
    {"chou", 26}, {"sun", 27}, {"alpha", 28}, {"ruby", 29}, {"yi sun-shin", 30},
    {"moskov", 31}, {"johnson", 32}, {"cyclops", 33}, {"estes", 34}, {"hilda", 35},
    {"aurora", 36}, {"lapu-lapu", 37}, {"vexana", 38}, {"roger", 39}, {"karrie", 40},
    {"gatotkaca", 41}, {"harley", 42}, {"irithel", 43}, {"grock", 44}, {"argus", 45},
    {"odette", 46}, {"lancelot", 47}, {"diggie", 48}, {"hylos", 49}, {"zhask", 50},
    {"helcurt", 51}, {"pharsa", 52}, {"lesley", 53}, {"jawhead", 54}, {"angela", 55},
    {"gusion", 56}, {"valir", 57}, {"martis", 58}, {"uranus", 59}, {"hanabi", 60},
    {"chang'e", 61}, {"kaja", 62}, {"selena", 63}, {"aldous", 64}, {"claude", 65},
    {"vale", 66}, {"leomord", 67}, {"lunox", 68}, {"hanzo", 69}, {"belerick", 70},
    {"kimmy", 71}, {"thamuz", 72}, {"harith", 73}, {"minsitthar", 74}, {"kadita", 75},
    {"faramis", 76}, {"badang", 77}, {"khufra", 78}, {"granger", 79}, {"guinevere", 80},
    {"esmeralda", 81}, {"terizla", 82}, {"xborg", 83}, {"ling", 84}, {"dyrroth", 85},
    {"lylia", 86}, {"baxia", 87}, {"masha", 88}, {"wanwan", 89}, {"silvanna", 90},
    {"cecilion", 91}, {"carmilla", 92}, {"atlas", 93}, {"popol and kupa", 94}, {"yu zhong", 95},
    {"luo yi", 96}, {"benedetta", 97}, {"khaleed", 98}, {"barats", 99}, {"brody", 100},
    {"yve", 101}, {"mathilda", 102}, {"paquito", 103}, {"gloo", 104}, {"beatrix", 105},
    {"phoveus", 106}, {"natan", 107}, {"aulus", 108}, {"aamon", 109}, {"valentina", 110},
    {"edith", 111}, {"floryn", 112}, {"yin", 113}, {"melissa", 114}, {"xavier", 115},
    {"julian", 116}, {"fredrinn", 117}, {"joy", 118}, {"novaria", 119}, {"arlott", 120},
    {"ixia", 121}, {"nolan", 122}, {"cici", 123}, {"chip", 124}, {"zhuxin", 125},
    {"suyou", 126}, {"lukas", 127}, {"kalea", 128}, {"zetian", 129},
    
    // ────────────── new heros ──────────────
    {"marcel",   130},
    {"obsidia",  131},
    {"sora",     132}
};

  for (const auto& pair : heroIconMap) {
    int iconIndex = pair.second;
    if (iconIndex < (int)(sizeof(iconHeroList) / sizeof(iconHeroList[0]))) {
        NSString *base64String = [NSString stringWithUTF8String:iconHeroList[iconIndex].c_str()];
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
        if (imageData) {
            UIImage *image = [UIImage imageWithData:imageData];
            if (image) {
                heroIconCache[pair.first] = image;           // English
            }
        }
    }
}


// Arabic Hero Names Map - نسخة محسنة جداً (أكثر من 3 نسخ لكل بطل + Saber)


static std::map<std::string, int> arabicHeroIconMap = {
    {"ميا", 1}, {"ميّا", 1}, {"مييا", 1}, {"ميا القمر", 1}, {"moonlight archer", 1},
    {"بالموند", 2}, {"بالمون", 2}, {"بالموند الوحش", 2}, {"balmond", 2},
    {"سيبر", 3}, {"سابر", 3}, {"سايبر", 3}, {"سايبر السيف المتجول", 3}, {"saber", 3},
    {"أليس", 4}, {"أليس ملكة الدم", 4}, {"alice", 4},
    {"نانا", 5}, {"نана", 5}, {"نانا القطة", 5}, {"nana", 5},
    {"تايجريل", 6}, {"تيجريل", 6}, {"تيغريل", 6}, {"تايغريل", 6}, {"tigreal", 6},
    {"ألوكارد", 7}, {"أليكارد", 7}, {"ألوكارد", 7}, {"alucard", 7},
    {"كارينا", 8}, {"كارينا", 8}, {"karina", 8},
    {"أكاي", 9}, {"اكاي", 9}, {"akai", 9},
    {"فرانكو", 10}, {"فرانكو", 10}, {"franco", 10},
    {"باين", 11}, {"بين", 11}, {"bane", 11},
    {"برونو", 12}, {"برونو", 12}, {"bruno", 12},
    {"كلينت", 13}, {"كلينت", 13}, {"clint", 13},
    {"رافايلا", 14}, {"رافييلا", 14}, {"رافاييلا", 14}, {"rafaela", 14},
    {"يودورا", 15}, {"إيودورا", 15}, {"يودورا", 15}, {"eudora", 15},
    {"زيلونغ", 16}, {"زيلونج", 16}, {"zilong", 16},
    {"فاني", 17}, {"فاني", 17}, {"fanny", 17},
    {"ليلى", 18}, {"ليلى", 18}, {"layla", 18},
    {"مينوتور", 19}, {"مينوتور", 19}, {"minotaur", 19},
    {"لوليتا", 20}, {"لوليتا", 20}, {"lolita", 20},
    {"هايابوسا", 21}, {"هايابوسا", 21}, {"hayabusa", 21},
    {"فريا", 22}, {"فريا", 22}, {"freya", 22},
    {"جورد", 23}, {"جورد", 23}, {"gord", 23},
    {"ناتاليا", 24}, {"ناتاليا", 24}, {"natalia", 24},
    {"كاجورا", 25}, {"كاجورا", 25}, {"kagura", 25},
    {"تشو", 26}, {"تشو", 26}, {"chou", 26},
    {"سون", 27}, {"صن", 27}, {"sun", 27},
    {"ألفا", 28}, {"ألفا", 28}, {"alpha", 28},
    {"روبي", 29}, {"روبي", 29}, {"ruby", 29},
    {"يي سون شين", 30}, {"يي سون-شين", 30}, {"يي سون شين", 30}, {"yi sun-shin", 30},
    {"موسكوف", 31}, {"موسكوف", 31}, {"moskov", 31},
    {"جونسون", 32}, {"جونسون", 32}, {"johnson", 32},
    {"سايكلوبس", 33}, {"سايكلوبس", 33}, {"cyclops", 33},
    {"إيستس", 34}, {"استيس", 34}, {"estes", 34},
    {"هيلدا", 35}, {"هيلدا", 35}, {"hilda", 35},
    {"أورورا", 36}, {"أورورا", 36}, {"aurora", 36},
    {"لابو لابو", 37}, {"لابو-لابو", 37}, {"لابولابو", 37}, {"lapu lapu", 37},
    {"فيكسانا", 38}, {"فيكسانا", 38}, {"vexana", 38},
    {"روجر", 39}, {"روجر", 39}, {"roger", 39},
    {"كاري", 40}, {"كاري", 40}, {"karrie", 40},
    {"جاتوتكاكا", 41}, {"جاتو", 41}, {"جاتوت", 41}, {"gatotkaca", 41},
    {"هارلي", 42}, {"هارلي", 42}, {"harley", 42},
    {"إريثيل", 43}, {"ايريثيل", 43}, {"irithel", 43},
    {"جروك", 44}, {"جروك", 44}, {"grock", 44},
    {"أرغوس", 45}, {"ارغوس", 45}, {"argus", 45},
    {"أوديت", 46}, {"اوديت", 46}, {"odette", 46},
    {"لانسيلوت", 47}, {"لانسيلوت", 47}, {"lancelot", 47},
    {"ديجي", 48}, {"ديجي", 48}, {"diggie", 48},
    {"هايلوس", 49}, {"هايلوس", 49}, {"hylos", 49},
    {"زاسك", 50}, {"زاسك", 50}, {"zhask", 50},
    {"هيلكورت", 51}, {"هيلكورت", 51}, {"helcurt", 51},
    {"فارسا", 52}, {"فارسا", 52}, {"pharsa", 52},
    {"ليزلي", 53}, {"ليزلي", 53}, {"lesley", 53},
    {"جوهيد", 54}, {"جاوهيد", 54}, {"jawhead", 54},
    {"أنجيلا", 55}, {"انجيلا", 55}, {"angela", 55},
    {"جوسيون", 56}, {"جوسيون", 56}, {"gusion", 56},
    {"فالير", 57}, {"فالير", 57}, {"valir", 57},
    {"مارتيس", 58}, {"مارتيس", 58}, {"martis", 58},
    {"اورانوس", 59}, {"أورانوس", 59}, {"uranus", 59},
    {"هانابي", 60}, {"هانابي", 60}, {"hanabi", 60},
    {"تشانغ", 61}, {"تشانغ اي", 61}, {"chang'e", 61},
    {"كاجا", 62}, {"كاجا", 62}, {"kaja", 62},
    {"سيلينا", 63}, {"سيلينا", 63}, {"selena", 63},
    {"ألدوس", 64}, {"الدوس", 64}, {"aldous", 64},
    {"كلود", 65}, {"كلاود", 65}, {"claude", 65},
    {"فايل", 66}, {"فال", 66}, {"vale", 66},
    {"ليومورد", 67}, {"ليومورد", 67}, {"leomord", 67},
    {"لونوكس", 68}, {"لونوكس", 68}, {"lunox", 68},
    {"هانزو", 69}, {"هانزو", 69}, {"hanzo", 69},
    {"بيليريك", 70}, {"بيليريك", 70}, {"belerick", 70},
    {"كيمي", 71}, {"كيمي", 71}, {"kimmy", 71},
    {"ثاموز", 72}, {"ثاموز", 72}, {"thamuz", 72},
    {"هاريث", 73}, {"هاريث", 73}, {"harith", 73},
    {"مينسيتار", 74}, {"مينسيثار", 74}, {"minsitthar", 74},
    {"كاديتا", 75}, {"كاديتا", 75}, {"kadita", 75},
    {"فاراميس", 76}, {"فاراميس", 76}, {"faramis", 76},
    {"بادانج", 77}, {"بادانغ", 77}, {"badang", 77},
    {"خفرع", 78}, {"خفرع", 78}, {"khufra", 78},
    {"غرينجر", 79}, {"غرانجر", 79}, {"granger", 79},
    {"غوينيفير", 80}, {"جوينيفير", 80}, {"guinevere", 80},
    {"إزميرالدا", 81}, {"ازميرالدا", 81}, {"esmeralda", 81},
    {"تيريزلا", 82}, {"تيريزلا", 82}, {"terizla", 82},
    {"إكس بورج", 83}, {"إكسبورغ", 83}, {"xborg", 83},
    {"لينج", 84}, {"لينغ", 84}, {"ling", 84},
    {"ديروث", 85}, {"ديروث", 85}, {"dyrroth", 85},
    {"ليليا", 86}, {"ليليا", 86}, {"lylia", 86},
    {"باكسيا", 87}, {"باكسيا", 87}, {"baxia", 87},
    {"ماشا", 88}, {"ماشا", 88}, {"masha", 88},
    {"وان وان", 89}, {"وانوان", 89}, {"wanwan", 89},
    {"سيلفانا", 90}, {"سيلفانا", 90}, {"silvanna", 90},
    {"سيسيليون", 91}, {"سيسيليون", 91}, {"cecilion", 91},
    {"كارميلا", 92}, {"كارميلا", 92}, {"carmilla", 92},
    {"أطلس", 93}, {"اطلس", 93}, {"atlas", 93},
    {"بوبول وكوبا", 94}, {"بوبول", 94}, {"بوبول و كوبا", 94}, {"popol and kupa", 94},
    {"يو زونغ", 95}, {"يو زونج", 95}, {"yu zhong", 95},
    {"لو يي", 96}, {"لو يي", 96}, {"luo yi", 96},
    {"بينديتا", 97}, {"بينديتا", 97}, {"benedetta", 97},
    {"خالد", 98}, {"خالد", 98}, {"khaleed", 98},
    {"باراتس", 99}, {"باراتس", 99}, {"barats", 99},
    {"برودي", 100}, {"برودي", 100}, {"brody", 100},
    {"إيف", 101}, {"ايف", 101}, {"yve", 101},
    {"ماثيلدا", 102}, {"ماثيلدا", 102}, {"mathilda", 102},
    {"باكيتو", 103}, {"باكيتو", 103}, {"paquito", 103},
    {"غلوو", 104}, {"جلو", 104}, {"gloo", 104},
    {"بياتريكس", 105}, {"بياتريكس", 105}, {"beatrix", 105},
    {"فوفيوس", 106}, {"فوفيوس", 106}, {"phoveus", 106},
    {"ناتان", 107}, {"ناتان", 107}, {"natan", 107},
    {"أولوس", 108}, {"اولوس", 108}, {"aulus", 108},
    {"آمون", 109}, {"امون", 109}, {"aamon", 109},
    {"فالنتينا", 110}, {"فالنتينا", 110}, {"valentina", 110},
    {"إديث", 111}, {"اديث", 111}, {"edith", 111},
    {"فلورين", 112}, {"فلورين", 112}, {"floryn", 112},
    {"يين", 113}, {"يين", 113}, {"yin", 113},
    {"ميليسا", 114}, {"ميليسا", 114}, {"melissa", 114},
    {"شافير", 115}, {"زافيير", 115}, {"xavier", 115},
    {"جوليان", 116}, {"جووليان", 116}, {"julian", 116},
    {"فريدرين", 117}, {"فردين", 117}, {"fredrinn", 117},
    {"جوي", 118}, {"جوي", 118}, {"joy", 118},
    {"نوفاريا", 119}, {"نوفاريا", 119}, {"novaria", 119},
    {"أرلوت", 120}, {"ارلوت", 120}, {"arlott", 120},
    {"إكسيا", 121}, {"ايكسيا", 121}, {"ixia", 121},
    {"نولان", 122}, {"نولان", 122}, {"nolan", 122},
    {"سيسيليا", 123}, {"سيسي", 123}, {"cici", 123},
    {"تشيب", 124}, {"تشيب", 124}, {"chip", 124},
    {"زو شين", 125}, {"زو شين", 125}, {"zhuxin", 125},
    {"سويو", 126}, {"سويو", 126}, {"suyou", 126},
    {"لوكاس", 127}, {"لوكاس", 127}, {"lukas", 127},
    {"كاليا", 128}, {"كاليا", 128}, {"kalea", 128},
    {"زيتيان", 129}, {"زيتيان", 129}, {"zetian", 129},
    
    // الأبطال الجدد 2025-2026
    {"مارسيل", 130}, {"مارسيل", 130}, {"marcel", 130},
    {"أوبسيديا", 131}, {"اوبسيديا", 131}, {"obsidia", 131},
    {"سورا", 132}, {"سورا", 132}, {"sora", 132}
};

for (const auto& pair : arabicHeroIconMap) {
    int iconIndex = pair.second;
    if (iconIndex < (int)(sizeof(iconHeroList) / sizeof(iconHeroList[0]))) {
        NSString *base64String = [NSString stringWithUTF8String:iconHeroList[iconIndex].c_str()];
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
        if (imageData) {
            UIImage *image = [UIImage imageWithData:imageData];
            if (image) {
                heroIconCache[pair.first] = image;           // Arabic
            }
        }
    }
}
    // Monster Icons
    static std::map<int, int> monsterIconMap = {
        {2002, 1}, {2003, 2}, {2004, 3}, {2005, 4}, {2006, 5},
        {2008, 6}, {2009, 7}, {2011, 8}, {2012, 9}, {2056, 10}, {2058, 11}
    };
    
    for (const auto& pair : monsterIconMap) {
        int iconIndex = pair.second;
        if (iconIndex < (int)(sizeof(MonsterList) / sizeof(MonsterList[0]))) {
            NSString *base64String = [NSString stringWithUTF8String:MonsterList[iconIndex].c_str()];
            NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
            if (imageData) {
                UIImage *image = [UIImage imageWithData:imageData];
                if (image) {
                    monsterIconCache[pair.first] = image;
                }
            }
        }
    }
    
    cacheInitialized = true;
}

// UnityFramework loader
static bool OpenUnityFrameworkIfNeeded() {
    if (g_UnityFrameworkHandle) return true;
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *frameworkPath = [bundlePath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
    void *h = dlopen([frameworkPath UTF8String], RTLD_NOLOAD);
    if (!h) {
        h = dlopen([frameworkPath UTF8String], RTLD_LAZY | RTLD_LOCAL);
        if (!h) {
            return false;
        }
    }
    g_UnityFrameworkHandle = h;
    baseAddress = (uintptr_t)g_UnityFrameworkHandle;
    return true;
}

// Il2Cpp helpers
extern "C" void Il2CppAttach(const char *name) {
    if (!g_UnityFrameworkHandle && !OpenUnityFrameworkIfNeeded()) {
        return;
    }
    il2cpp_class_init = (il2cpp_class_init_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_runtime_class_init");
    il2cpp_class_from_name = (il2cpp_class_from_name_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_class_from_name");
    il2cpp_class_get_field_from_name = (il2cpp_class_get_field_from_name_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_class_get_field_from_name");
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_class_get_method_from_name");
    il2cpp_class_get_type = (il2cpp_class_get_type_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_class_get_type");
    il2cpp_type_get_object = (il2cpp_type_get_object_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_type_get_object");
    il2cpp_field_get_offset = (il2cpp_field_get_offset_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_field_get_offset");
    il2cpp_class_get_name = (il2cpp_class_get_name_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_class_get_name");
    il2cpp_class_get_namespace = (il2cpp_class_get_namespace_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_class_get_namespace");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_assembly_get_image");
    il2cpp_image_get_name = (il2cpp_image_get_name_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_image_get_name");
    il2cpp_image_get_class_count = (il2cpp_image_get_class_count_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_image_get_class_count");
    il2cpp_image_get_class = (il2cpp_image_get_class_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_image_get_class");
    il2cpp_domain_get = (il2cpp_domain_get_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_domain_get_assemblies");
    il2cpp_class_get_static_field_data = (il2cpp_class_get_static_field_data_ptr)dlsym(g_UnityFrameworkHandle, "il2cpp_class_value_size");
}

// IL2CPP Helper Functions
void *Il2CppGetImageByName(const char *image) {
    size_t size;
    const Il2CppAssembly** assemblies = il2cpp_domain_get_assemblies(il2cpp_domain_get(), &size);
    if (!assemblies) {
        return NULL;
    }
    for (size_t i = 0; i < size; ++i) {
        const Il2CppImage* img = il2cpp_assembly_get_image(assemblies[i]);
        if (!img) continue;
        if (strcmp(il2cpp_image_get_name(img), image) == 0) {
            return (void*)img;
        }
    }
    return NULL;
}

void *Il2CppGetClassType(const char *image, const char *namespaze, const char *clazz) {
    Il2CppImage* img = (Il2CppImage*)Il2CppGetImageByName(image);
    if (!img) {
        return NULL;
    }
    Il2CppClass* kl = il2cpp_class_from_name(img, namespaze, clazz);
    if (!kl) {
        return NULL;
    }
    il2cpp_class_init(kl);
    return (void*)il2cpp_class_get_type(kl);
}

size_t Il2CppGetFieldOffset(const char *image, const char *namespaze, const char *clazz, const char *name) {
    Il2CppImage* img = (Il2CppImage*)Il2CppGetImageByName(image);
    if (!img) {
        return -1;
    }
    Il2CppClass* kl = il2cpp_class_from_name(img, namespaze, clazz);
    if (!kl) {
        return -1;
    }
    il2cpp_class_init(kl);
    FieldInfo* field = il2cpp_class_get_field_from_name(kl, name);
    if (!field) {
        return -1;
    }
    return (size_t)il2cpp_field_get_offset(field);
}

void *Il2CppGetMethodOffset(const char *image, const char *namespaze, const char *clazz, const char *name, int argsCount) {
    Il2CppImage* img = (Il2CppImage*)Il2CppGetImageByName(image);
    if (!img) {
        return NULL;
    }
    Il2CppClass* kl = il2cpp_class_from_name(img, namespaze, clazz);
    if (!kl) {
        return NULL;
    }
    il2cpp_class_init(kl);
    const MethodInfo* method = il2cpp_class_get_method_from_name(kl, name, argsCount);
    if (!method) {
        return NULL;
    }
    return (void*)method->methodPointer;
}

unsigned long Il2CppGetStaticFieldOffset(const char *image, const char *namespaze, const char *clazz, const char *name) {
    Il2CppImage* img = (Il2CppImage*)Il2CppGetImageByName(image);
    if (!img) {
        return 0;
    }
    Il2CppClass* kl = il2cpp_class_from_name(img, namespaze, clazz);
    if (!kl) {
        return 0;
    }
    il2cpp_class_init(kl);
    FieldInfo* field = il2cpp_class_get_field_from_name(kl, name);
    if (!field || !(field->type->attrs & 0x0010)) {
        return 0;
    }
    void* static_data = il2cpp_class_get_static_field_data(kl);
    if (!static_data) {
        return 0;
    }
    return (unsigned long)((char*)static_data + field->offset);
}

// Safe memory read helpers
bool safe_read_ptr(void *src, void **out) {
    if (!src) { *out = NULL; return false; }
    __builtin_memcpy(out, src, sizeof(void*));
    return *out != NULL;
}

bool safe_read_int(void *src, int *out) {
    if (!src) { *out = 0; return false; }
    __builtin_memcpy(out, src, sizeof(int));
    return true;
}

void safe_memcpy(void *dst, const void *src, size_t len) {
    if (!src || !dst) return;
    __builtin_memcpy(dst, src, len);
}

// ====================== ESPLine2View Implementation (ألوان مختلفة + مسافات + حماية) ======================
@implementation ESPLine2View

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self->_playerPosition = Vector3::zero();
        self->_enemies.clear();
    }
    return self;
}

- (void)updatePlayer:(Vector3)pos enemies:(const std::vector<EnemyData>&)enemies {
    self->_playerPosition = pos;
    self->_enemies = enemies;
    [self redrawLinesAndDistances];
}

// تنظيف الـ Layers
- (void)clearAllLayers {
    for (CALayer *layer in [self.layer.sublayers copy]) {
        [layer removeFromSuperlayer];
    }
}

// ====================== النسخة المحسنة والنهائية ======================
- (void)redrawLinesAndDistances {
    [self clearAllLayers];
    
    if (!showESPLine2 || self->_enemies.empty()) return;
    
    static void *g_mainCamera = NULL;
    void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
    if (!mainCameraMethod) return;
    
    g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
    if (!g_mainCamera || !Camera_WorldToScreenPoint) return;
    
    CGPoint screenCenter = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
    CGFloat scale = g_screenScale;
    
    @try {
        for (const auto& enemy : self->_enemies) {
            Vector3 screenPos = Camera_WorldToScreenPoint(g_mainCamera, enemy.position);
            if (screenPos.z <= 0) continue;
            
            CGFloat px = screenPos.x / scale;
            CGFloat py = (self.bounds.size.height * scale - screenPos.y) / scale;
            px = fmax(0.0f, fmin(self.bounds.size.width, px));
            py = fmax(0.0f, fmin(self.bounds.size.height, py));
            
            float distance = (self->_playerPosition - enemy.position).magnitude();
            
            // ====================== تحديد اللون ======================
            UIColor *baseColor;
            CGFloat finalAlpha;
            
            if (distance <= 17.0f) {
                // أحمر واضح وقوي لما يكون قريب
                baseColor = [UIColor colorWithRed:1.0 green:0.08 blue:0.08 alpha:1.0];
                finalAlpha = 0.85;        // أعلى شفافية للأحمر
            } else {
                // لون البطل العادي
                baseColor = GetHeroColor(enemy.heroName ?: @"Unknown");
                finalAlpha = 0.38;        // شفافية 38% للخطوط البعيدة
            }
            
            // تطبيق الشفافية الصحيحة
            CGFloat r, g, b, a;
            [baseColor getRed:&r green:&g blue:&b alpha:&a];
            UIColor *finalLineColor = [UIColor colorWithRed:r green:g blue:b alpha:finalAlpha];
            
            // ====================== رسم الخط ======================
            CAShapeLayer *lineLayer = [CAShapeLayer layer];
            lineLayer.frame = self.bounds;
            lineLayer.strokeColor = finalLineColor.CGColor;
            lineLayer.lineWidth = 2.5f;
            lineLayer.lineJoin = kCALineJoinRound;
            lineLayer.lineCap = kCALineCapRound;
            lineLayer.shadowColor = [UIColor blackColor].CGColor;
            lineLayer.shadowOpacity = 0.4f;
            lineLayer.shadowRadius = 2.0f;
            
            UIBezierPath *path = [UIBezierPath bezierPath];
            [path moveToPoint:screenCenter];
            [path addLineToPoint:CGPointMake(px, py)];
            lineLayer.path = path.CGPath;
            
            [self.layer addSublayer:lineLayer];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[ESPLine2View] Exception: %@", e.reason);
    }
}
@end


@implementation ESPBoxView

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    CGContextClearRect(ctx, rect);
    
    if (!showESPBoxes || self->enemies.empty()) return;
    
    static void *g_mainCamera = NULL;
    void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
    if (!mainCameraMethod) return;
    
    g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
    if (!g_mainCamera || !Camera_WorldToScreenPoint) return;
    
    @try {
        CGContextSetLineWidth(ctx, 2.2f);
        CGFloat w = rect.size.width;
        CGFloat h = rect.size.height;
        
        for (const auto& enemy : self->enemies) {
            Vector3 screenPos = Camera_WorldToScreenPoint(g_mainCamera, enemy.position);
            if (screenPos.z <= 0) continue;
            
            CGFloat px = screenPos.x / g_screenScale;
            CGFloat py = (h * g_screenScale - screenPos.y) / g_screenScale;
            
            px = fmax(0.0f, fmin(w, px));
            py = fmax(0.0f, fmin(h, py));
            
            // حجم أكبر من الـ Icon
            CGFloat boxWidth = 48.0f;   // زاد عن 38
            CGFloat boxHeight = boxWidth * 1.75f;
            
            CGRect boxRect = CGRectMake(px - boxWidth/2, py - boxHeight/2 - 12, boxWidth, boxHeight);
            
            CGContextSetStrokeColorWithColor(ctx, [UIColor redColor].CGColor);
            CGContextStrokeRect(ctx, boxRect);
        }
    } @catch (NSException *e) {}
}
@end

@implementation ESPIconView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self.playerIconPool = [NSMutableArray arrayWithCapacity:25];
        self.monsterIconPool = [NSMutableArray arrayWithCapacity:15];
    }
    return self;
}

- (void)updateEnemies:(const std::vector<EnemyData>&)enemies {
    @try {
        if (!showESPIcons) {
            [self hideAllPlayerIcons];
            return;
        }
        
        NSInteger needed = enemies.size();
        while (self.playerIconPool.count < needed) {
            UIImageView *iv = [[UIImageView alloc] init];
            iv.contentMode = UIViewContentModeScaleAspectFit;
            iv.tag = 100;
            [self addSubview:iv];
            [self.playerIconPool addObject:iv];
        }
        
        for (NSInteger i = needed; i < self.playerIconPool.count; i++) {
            self.playerIconPool[i].hidden = YES;
        }
        
        if (enemies.empty()) return;
        
        static void *g_mainCamera = NULL;
        void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
        if (!mainCameraMethod) return;
        g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
        if (!g_mainCamera || !Camera_WorldToScreenPoint) return;
        
        CGFloat scale = g_screenScale;
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        
        for (size_t i = 0; i < enemies.size(); ++i) {
            Vector3 screenPos = Camera_WorldToScreenPoint(g_mainCamera, enemies[i].position);
            if (screenPos.z <= 0) {
                self.playerIconPool[i].hidden = YES;
                continue;
            }
            
            CGFloat px = screenPos.x / scale;
            CGFloat py = (h * scale - screenPos.y) / scale;
            px = fmax(15.0f, fmin(w - 15.0f, px));
            py = fmax(15.0f, fmin(h - 15.0f, py));
            
            UIImageView *iv = self.playerIconPool[i];
            iv.hidden = NO;
            iv.frame = CGRectMake(px - 8.0f, py - 8.0f, 16.0f, 16.0f);
            
            NSString *key = enemies[i].heroName ?: @"Unknown";
            std::string stdKey = [key UTF8String];
           auto it = heroIconCache.find(stdKey);
UIImage *icon = (it != heroIconCache.end()) ? it->second : heroIconCache["Unknown"];
iv.image = icon;
        }
    }
    @catch (NSException *e) {
        NSLog(@"[ESPIconView] Exception in updateEnemies: %@", e.reason);
    }
}

- (void)updateMonsters:(const std::vector<EnemyData>&)monsters {
    @try {
        if (!showESPMonsterIcons) {
            [self hideAllMonsterIcons];
            return;
        }
        
        NSInteger needed = monsters.size();
        while (self.monsterIconPool.count < needed) {
            UIImageView *iv = [[UIImageView alloc] init];
            iv.contentMode = UIViewContentModeScaleAspectFit;
            iv.tag = 999;
            [self addSubview:iv];
            [self.monsterIconPool addObject:iv];
        }
        
        for (NSInteger i = needed; i < self.monsterIconPool.count; i++) {
            self.monsterIconPool[i].hidden = YES;
        }
        
        if (monsters.empty()) return;
        
        static void *g_mainCamera = NULL;
        void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
        if (!mainCameraMethod) return;
        g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
        if (!g_mainCamera || !Camera_WorldToScreenPoint) return;
        
        CGFloat scale = g_screenScale;
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        
        for (size_t i = 0; i < monsters.size(); ++i) {
            Vector3 screenPos = Camera_WorldToScreenPoint(g_mainCamera, monsters[i].position);
            if (screenPos.z <= 0) {
                self.monsterIconPool[i].hidden = YES;
                continue;
            }
            
            CGFloat px = screenPos.x / scale;
            CGFloat py = (h * scale - screenPos.y) / scale;
            
            if (px < 0 || px > w || py < 0 || py > h) {
                self.monsterIconPool[i].hidden = YES;
                continue;
            }
            
            UIImageView *iv = self.monsterIconPool[i];
            iv.hidden = NO;
            iv.frame = CGRectMake(px - 8.0f, py - 8.0f, 16.0f, 16.0f);
            iv.image = monsterIconCache[monsters[i].monsterId];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[ESPIconView] Exception in updateMonsters: %@", e.reason);
    }
}

- (void)hideAllPlayerIcons {
    for (UIImageView *iv in self.playerIconPool) iv.hidden = YES;
}

- (void)hideAllMonsterIcons {
    for (UIImageView *iv in self.monsterIconPool) iv.hidden = YES;
}

@end





// ====================== ESPHealthView Implementation ======================
@implementation ESPHealthView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

// تحديث بارات الصحة للأعداء
- (void)updateEnemies:(const std::vector<EnemyData>&)enemies {
    [self updateHealthBarsForEnemies:enemies];
}

// تحديث بارات الصحة لكل اللاعبين
- (void)updateAllEntities:(const std::vector<AllEntityData>&)allEntities {
    [self updateHealthBarsForAllEntities:allEntities];
}

// تحديث بارات الصحة للوحوش
- (void)updateMonsters:(const std::vector<EnemyData>&)monsters {
    [self updateHealthBarsForMonsters:monsters];
}

// ==================== بارات الصحة للأعداء ====================
- (void)updateHealthBarsForEnemies:(const std::vector<EnemyData>&)enemies {
    @try {
        [self clearHealthBarsWithTag:100];
        
        if (!showESPHealth || enemies.empty()) return;
        
        static void *g_mainCamera = NULL;
        void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
        if (!mainCameraMethod) return;
        
        g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
        if (!g_mainCamera || !Camera_WorldToScreenPoint) return;
        
        CGFloat scale = g_screenScale;
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        
        for (size_t i = 0; i < enemies.size(); ++i) {
            Vector3 screenPos = Camera_WorldToScreenPoint(g_mainCamera, enemies[i].position);
            if (screenPos.z <= 0) continue;
            
            CGFloat px = screenPos.x / scale;
            CGFloat py = (h * scale - screenPos.y) / scale;
            
            px = fmax(30.0f, fmin(w - 30.0f, px));
            py = fmax(30.0f, fmin(h - 30.0f, py));
            
            [self createHealthBarAtX:px y:py hp:enemies[i].hp hpMax:enemies[i].hpMax tag:100 + (NSInteger)i];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[ESPHealthView] Exception in updateEnemies: %@", e.reason);
    }
}

// ==================== بارات الصحة لكل اللاعبين ====================
- (void)updateHealthBarsForAllEntities:(const std::vector<AllEntityData>&)allEntities {
    @try {
        [self clearHealthBarsWithTag:200];
        
        if (!showAllEntityHP || allEntities.empty()) return;
        
        static void *g_mainCamera = NULL;
        void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
        if (!mainCameraMethod) return;
        
        g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
        if (!g_mainCamera || !Camera_WorldToScreenPoint) return;
        
        CGFloat scale = g_screenScale;
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        
        for (size_t i = 0; i < allEntities.size(); ++i) {
            Vector3 screenPos = Camera_WorldToScreenPoint(g_mainCamera, allEntities[i].position);
            if (screenPos.z <= 0) continue;
            
            CGFloat px = screenPos.x / scale;
            CGFloat py = (h * scale - screenPos.y) / scale;
            
            px = fmax(30.0f, fmin(w - 30.0f, px));
            py = fmax(30.0f, fmin(h - 30.0f, py));
            
            [self createHealthBarAtX:px y:py hp:allEntities[i].hp hpMax:allEntities[i].hpMax tag:200 + (NSInteger)i];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[ESPHealthView] Exception in updateAllEntities: %@", e.reason);
    }
}

// ==================== بارات الصحة للوحوش (عمودي وصغير) ====================
- (void)updateHealthBarsForMonsters:(const std::vector<EnemyData>&)monsters {
    @try {
        [self clearHealthBarsWithTag:300];
        
        if (!showMonstersHP || monsters.empty()) return;
        
        static void *g_mainCamera = NULL;
        void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
        if (!mainCameraMethod) return;
        
        g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
        if (!g_mainCamera || !Camera_WorldToScreenPoint) return;
        
        CGFloat scale = g_screenScale;
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        
        for (size_t i = 0; i < monsters.size(); ++i) {
            Vector3 screenPos = Camera_WorldToScreenPoint(g_mainCamera, monsters[i].position);
            if (screenPos.z <= 0) continue;
            
            CGFloat px = screenPos.x / scale;
            CGFloat py = (h * scale - screenPos.y) / scale;
            
            if (px < 0 || px > w || py < 0 || py > h) continue;
            
            [self createVerticalMonsterHealthBarAtX:px 
                                               y:py 
                                             hp:monsters[i].hp 
                                           hpMax:monsters[i].hpMax 
                                            tag:300 + (NSInteger)i];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[ESPHealthView] Exception in updateMonsters: %@", e.reason);
    }
}

// ==================== دالة بار الصحة الأفقي (للاعبين) ====================
- (void)createHealthBarAtX:(CGFloat)px y:(CGFloat)py hp:(int)hp hpMax:(int)hpMax tag:(NSInteger)tag {
    if (hpMax <= 0) return;
    
    float percent = (float)hp / (float)hpMax;
    
    // خلفية البار
    UIView *bgView = [[UIView alloc] initWithFrame:CGRectMake(px - 32, py + 12, 64, 6.5)];
    bgView.backgroundColor = [UIColor blackColor];
    bgView.layer.cornerRadius = 2.0f;
    bgView.tag = tag;
    [self addSubview:bgView];
    
    // البار الممتلئ
    UIView *fillView = [[UIView alloc] initWithFrame:CGRectMake(px - 32, py + 12, 64 * percent, 6.5)];
    fillView.backgroundColor = (percent > 0.6f) ? [UIColor greenColor] :
                               (percent >= 0.3f) ? [UIColor yellowColor] : [UIColor redColor];
    fillView.layer.cornerRadius = 2.0f;
    fillView.tag = tag;
    [self addSubview:fillView];
    
    // النص HP
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(px - 32, py + 10, 64, 9)];
    label.text = [NSString stringWithFormat:@"%d", hp];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:11.0f];
    label.textAlignment = NSTextAlignmentCenter;
    label.shadowColor = [UIColor blackColor];
    label.shadowOffset = CGSizeMake(0.5, 0.5);
    label.tag = tag;
    [self addSubview:label];
}

// ==================== دالة بار صحة عمودي صغير للوحوش ====================
- (void)createVerticalMonsterHealthBarAtX:(CGFloat)px 
                                      y:(CGFloat)py 
                                    hp:(int)hp 
                                  hpMax:(int)hpMax 
                                   tag:(NSInteger)tag {
    if (hpMax <= 0) return;
    
    float percent = (float)hp / (float)hpMax;
    
    // حجم صغير جداً (عمودي)
    CGFloat barWidth = 5.5f;
    CGFloat barHeight = 28.0f;
    
    // خلفية البار
    UIView *bgView = [[UIView alloc] initWithFrame:CGRectMake(px - barWidth/2, py - barHeight - 12, barWidth, barHeight)];
    bgView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.75];
    bgView.layer.cornerRadius = 1.5f;
    bgView.tag = tag;
    [self addSubview:bgView];
    
    // البار الممتلئ
    CGFloat fillHeight = barHeight * percent;
    UIView *fillView = [[UIView alloc] initWithFrame:CGRectMake(px - barWidth/2, 
                                                                py - fillHeight - 12, 
                                                                barWidth, 
                                                                fillHeight)];
    
    if (percent > 0.6f) {
        fillView.backgroundColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.1 alpha:0.95];
    } else if (percent >= 0.35f) {
        fillView.backgroundColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:0.95];
    } else {
        fillView.backgroundColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.1 alpha:0.95];
    }
    
    fillView.layer.cornerRadius = 1.5f;
    fillView.tag = tag;
    [self addSubview:fillView];
    
    // نص HP صغير
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(px - 12, py - barHeight - 22, 24, 10)];
    label.text = [NSString stringWithFormat:@"%d", hp];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:8.0f];
    label.textAlignment = NSTextAlignmentCenter;
    label.tag = tag;
    [self addSubview:label];
}

// تنظيف البارات حسب الـ tag
- (void)clearHealthBarsWithTag:(NSInteger)baseTag {
    for (UIView *subview in self.subviews.copy) {
        if (subview.tag >= baseTag && subview.tag < baseTag + 1000) {
            [subview removeFromSuperview];
        }
    }
}

@end

// Resolve Offsets & Methods (Cached)
static bool offsetsResolved = false;
static void ResolveIl2CppOffsetsAndMethods() {
    if (offsetsResolved) return;
    off_m_LocalPlayerShow = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "BattleManager", "m_LocalPlayerShow");
    off_m_ShowPlayers = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "BattleManager", "m_ShowPlayers");
    off_m_ShowMonsters = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "BattleManager", "m_ShowMonsters");
    off_m_bSameCampType = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowEntity", "m_bSameCampType");
    off_m_bDeath = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowEntity", "m_bDeath");
    off__logicFighter = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowEntity", "_logicFighter");
    off_m_HeroName = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowPlayer", "m_HeroName");
    off_m_RoleName = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowEntity", "m_RoleName");
    off_m_Hp = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowEntity", "m_Hp");
    off_m_HpMax = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowEntity", "m_HpMax");
    off_m_ID = Il2CppGetFieldOffset("Assembly-CSharp.dll", "", "ShowEntity", "m_ID");
    void *mpos = Il2CppGetMethodOffset("Assembly-CSharp.dll", "", "ShowEntity", "get_Position", 0);
    if (mpos) fn_ShowEntity_get_Position = reinterpret_cast<Vector3(*)(void*)>(mpos);
    void *mlf = Il2CppGetMethodOffset("Assembly-CSharp.dll", "", "ShowEntity", "get_logicFighter", 0);
    if (mlf) fn_ShowEntity_get_logicFighter = reinterpret_cast<void*(*)(void*)>(mlf);
    void *worldToScreen = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "WorldToScreenPoint", 1);
    if (worldToScreen) Camera_WorldToScreenPoint = reinterpret_cast<Vector3(*)(void*, Vector3)>(worldToScreen);
    void *getFov = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_fieldOfView", 0);
    if (getFov) Camera_get_fieldOfView = reinterpret_cast<float(*)(void*)>(getFov);
    void *setFov = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "set_fieldOfView", 1);
    if (setFov) Camera_set_fieldOfView = reinterpret_cast<void(*)(void*, float)>(setFov);
    void *setResolution = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Screen", "SetResolution", 3);
    if (setResolution) Screen_SetResolution = reinterpret_cast<void(*)(int, int, bool)>(setResolution);
    offsetsResolved = true;
}

// Attempt to find BattleManager singleton
void TryFindBattleManagerSingleton() {
    if (BattleManager) return;
    void *klass = Il2CppGetClassType("Assembly-CSharp.dll", "", "BattleManager");
    if (!klass) {
        klass = Il2CppGetClassType("Assembly-CSharp.dll", "", "LogicBattleManager");
        if (!klass) return;
    }
    const char *candidates[] = { "Instance", "instance", "s_instance", "_instance", "s_Instance", NULL };
    for (int i = 0; i < 5; i++) {
        unsigned long instanceAddr = Il2CppGetStaticFieldOffset("Assembly-CSharp.dll", "", "LogicBattleManager", candidates[i]);
        if (instanceAddr) {
            void *val = NULL;
            safe_read_ptr((void*)instanceAddr, &val);
            if (val) { BattleManager = val; return; }
        }
        instanceAddr = Il2CppGetStaticFieldOffset("Assembly-CSharp.dll", "", "BattleManager", candidates[i]);
        if (instanceAddr) {
            void *val = NULL;
            safe_read_ptr((void*)instanceAddr, &val);
            if (val) { BattleManager = val; return; }
        }
    }
}

// FOV Modification
void SetFOV(float fovValue) {
    void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
    void *g_mainCamera = NULL;
    if (mainCameraMethod) {
        g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
    }
    if (!g_mainCamera || !Camera_set_fieldOfView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (fovStatusLabel) fovStatusLabel.text = !g_mainCamera ? @"FOV: No Main Camera" : @"FOV: Function Error";
        });
        return;
    }
    if (!fovModified) {
        float currentFOV = Camera_get_fieldOfView ? Camera_get_fieldOfView(g_mainCamera) : 60.0f;
        originalFOV = (currentFOV > 0.0f) ? currentFOV : 60.0f;
        fovModified = true;
    }
    Camera_set_fieldOfView(g_mainCamera, fovValue);
    selectedFOV = fovValue;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (fovStatusLabel) fovStatusLabel.text = [NSString stringWithFormat:@"FOV: %.1f", fovValue];
    });
}

void ResetFOV() {
    void *mainCameraMethod = Il2CppGetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
    void *g_mainCamera = NULL;
    if (mainCameraMethod) {
        g_mainCamera = reinterpret_cast<void*(*)()>(mainCameraMethod)();
    }
    if (!g_mainCamera || !Camera_set_fieldOfView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (fovStatusLabel) fovStatusLabel.text = !g_mainCamera ? @"FOV: No Main Camera" : @"FOV: Function Error";
        });
        return;
    }
    Camera_set_fieldOfView(g_mainCamera, originalFOV);
    fovModified = false;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (fovStatusLabel) fovStatusLabel.text = [NSString stringWithFormat:@"FOV: %.1f (Default)", originalFOV];
    });
}


static auto lastESPUpdate = std::chrono::steady_clock::now();

// ====================== Helper Functions ======================

static void ClearAllESPViews() {
    std::vector<EnemyData> emptyEnemies;
    std::vector<AllEntityData> emptyAll;

    if (espLine2View) [espLine2View updatePlayer:Vector3::zero() enemies:emptyEnemies];
    if (espBoxView) [espBoxView updateEnemies:emptyEnemies];
    if (espIconView) {
        [espIconView updateEnemies:emptyEnemies];
        [espIconView updateMonsters:emptyEnemies];
    }
    if (espHealthView) {
        [espHealthView updateEnemies:emptyEnemies];
        [espHealthView updateAllEntities:emptyAll];
        [espHealthView updateMonsters:emptyEnemies];
    }
}

static void ProcessPlayers(void* localPlayer, std::vector<EnemyData>& enemies, std::vector<AllEntityData>& allEntities) {
    Il2CppList* players = NULL;
    if (off_m_ShowPlayers != (size_t)-1) {
        safe_read_ptr((void*)((uintptr_t)BattleManager + off_m_ShowPlayers), (void**)&players);
    }
    if (!players || !players->_items || !players->_items->_vector) return;

    int count = players->_size;
    for (int i = 0; i < count; i++) {
        void* obj = NULL;
        if (!safe_read_ptr(&players->_items->_vector[i], &obj) || !obj) continue;

        uint8_t sameByte = 0, deathByte = 0;
        bool same = false, dead = false;

        if (off_m_bSameCampType != (size_t)-1) {
            safe_memcpy(&sameByte, (void*)((uintptr_t)obj + off_m_bSameCampType), 1);
            same = (sameByte != 0);
        }
        if (off_m_bDeath != (size_t)-1) {
            safe_memcpy(&deathByte, (void*)((uintptr_t)obj + off_m_bDeath), 1);
            dead = (deathByte != 0);
        }

        void* logicF = fn_ShowEntity_get_logicFighter ? fn_ShowEntity_get_logicFighter(obj) : NULL;
        if (!logicF && off__logicFighter != (size_t)-1) {
            safe_read_ptr((void*)((uintptr_t)obj + off__logicFighter), &logicF);
        }
        if (!logicF) continue;

        Vector3 pos = fn_ShowEntity_get_Position(obj);
        if (pos.x == 0 && pos.y == 0 && pos.z == 0) continue;

        // Read names and HP
        NSString *heroName = @"Unknown";
        if (off_m_HeroName != (size_t)-1) {
            Il2CppString* str = NULL;
            safe_read_ptr((void*)((uintptr_t)obj + off_m_HeroName), (void**)&str);
            if (str && str->length > 0) {
                heroName = [NSString stringWithCharacters:(const unichar*)str->chars length:str->length];
            }
        }

        NSString *roleName = @"Unknown";
        if (off_m_RoleName != (size_t)-1) {
            Il2CppString* str = NULL;
            safe_read_ptr((void*)((uintptr_t)obj + off_m_RoleName), (void**)&str);
            if (str && str->length > 0) {
                roleName = [NSString stringWithCharacters:(const unichar*)str->chars length:str->length];
            }
        }

        int32_t hp = 0, hpMax = 0;
        if (off_m_Hp != (size_t)-1) safe_read_int((void*)((uintptr_t)obj + off_m_Hp), &hp);
        if (off_m_HpMax != (size_t)-1) safe_read_int((void*)((uintptr_t)obj + off_m_HpMax), &hpMax);

        if (!dead) {
            AllEntityData allEntity{obj, pos, heroName, roleName, hp, hpMax};
            allEntities.push_back(allEntity);

            if (!same) {
                EnemyData enemy{obj, pos, heroName, roleName, hp, hpMax, 0};
                enemies.push_back(enemy);
            }
        }
    }
}

static void ProcessMonsters(std::vector<EnemyData>& monsters) {
    Il2CppList* monsterList = NULL;
    if (off_m_ShowMonsters != (size_t)-1) {
        safe_read_ptr((void*)((uintptr_t)BattleManager + off_m_ShowMonsters), (void**)&monsterList);
    }
    if (!monsterList || !monsterList->_items || !monsterList->_items->_vector) return;

    int count = monsterList->_size;
    static const int allowedMonsterIds[] = {2056, 2008, 2004, 2011, 2005, 2012, 2006, 2003, 2009, 2002, 2058};

    for (int i = 0; i < count; i++) {
        void* obj = NULL;
        if (!safe_read_ptr(&monsterList->_items->_vector[i], &obj) || !obj) continue;

        uint8_t deathByte = 0;
        if (off_m_bDeath != (size_t)-1) {
            safe_memcpy(&deathByte, (void*)((uintptr_t)obj + off_m_bDeath), 1);
            if (deathByte != 0) continue;
        }

        Vector3 pos = fn_ShowEntity_get_Position(obj);
        if (pos.x == 0 && pos.y == 0 && pos.z == 0) continue;

        int32_t hp = 0, hpMax = 0, monsterId = 0;
        if (off_m_Hp != (size_t)-1) safe_read_int((void*)((uintptr_t)obj + off_m_Hp), &hp);
        if (off_m_HpMax != (size_t)-1) safe_read_int((void*)((uintptr_t)obj + off_m_HpMax), &hpMax);
        if (off_m_ID != (size_t)-1) safe_read_int((void*)((uintptr_t)obj + off_m_ID), &monsterId);

        bool isAllowed = false;
        for (int id : allowedMonsterIds) {
            if (monsterId == id) { isAllowed = true; break; }
        }
        if (!isAllowed) continue;

        EnemyData monster{obj, pos, nil, @"Monster", hp, hpMax, monsterId};
        monsters.push_back(monster);
    }
}

static bool CheckMatchEnd(const std::vector<EnemyData>& enemies) {
    static int consecutiveFreezeFrames = 0;
    bool shouldClear = false;
    auto now = std::chrono::steady_clock::now();

    if (enemies.size() >= MIN_PLAYERS_TO_CHECK) {
        int frozenPlayers = 0;

        for (const auto& enemy : enemies) {
            void* entityPtr = enemy.showEntity;
            auto it = playerTrackMap.find(entityPtr);

          if (it == playerTrackMap.end()) {
    PlayerPositionTrack track;
    track.lastPos = enemy.position;
    track.lastUpdateTime = now;
    track.freezeCounter = 0;
    playerTrackMap[entityPtr] = track;
    continue;
}

            auto& track = it->second;
            float distMoved = (track.lastPos - enemy.position).magnitude();

            if (distMoved < POSITION_FREEZE_TOLERANCE) {
                if (std::chrono::duration_cast<std::chrono::milliseconds>(now - track.lastUpdateTime).count() > 400) {
                    track.freezeCounter++;
                }
            } else {
                track.freezeCounter = 0;
                track.lastPos = enemy.position;
            }
            track.lastUpdateTime = now;

            if (track.freezeCounter >= (FREEZE_THRESHOLD_FRAMES / updateInterval + 1)) {
                frozenPlayers++;
            }
        }

        float frozenRatio = static_cast<float>(frozenPlayers) / enemies.size();
        if (frozenRatio >= FROZEN_RATIO_THRESHOLD) {
            consecutiveFreezeFrames++;
            if (consecutiveFreezeFrames >= CONSECUTIVE_CONFIRM) {
                shouldClear = true;
            }
        } else {
            consecutiveFreezeFrames = 0;
        }
    } 
    else if (enemies.size() == 0 && g_enemies.size() >= MIN_PLAYERS_TO_CHECK) {
        consecutiveFreezeFrames++;
        if (consecutiveFreezeFrames >= 4) shouldClear = true;
    } else {
        consecutiveFreezeFrames = 0;
    }

    return shouldClear;
}

// ====================== Main Function ======================
static void UpdateESPData() {
    if (!offsetsResolved) ResolveIl2CppOffsetsAndMethods();

    // Throttling لتقليل اللاج
    auto now = std::chrono::steady_clock::now();
    if (std::chrono::duration_cast<std::chrono::milliseconds>(now - lastESPUpdate).count() < 65) {
        return;
    }
    lastESPUpdate = now;

    if (!BattleManager) {
        TryFindBattleManagerSingleton();
        if (!BattleManager) {
            if (!g_enemies.empty()) {
                g_enemies.clear();
                dispatch_async(dispatch_get_main_queue(), ^{ 
                    if (updateStatusLabel) updateStatusLabel.text = @"Update: No BattleManager";
                    if (enemyCountLabel) enemyCountLabel.text = @"Enemies Detected: 0";
                    ClearAllESPViews();
                });
            }
            return;
        }
    }

    std::vector<EnemyData> enemies;
    std::vector<AllEntityData> allEntities;
    std::vector<EnemyData> monsters;
    Vector3 selfPos = Vector3::zero();

    @try {
        void* localPlayer = NULL;
        if (off_m_LocalPlayerShow != (size_t)-1) {
            safe_read_ptr((void*)((uintptr_t)BattleManager + off_m_LocalPlayerShow), &localPlayer);
        }

        if (!localPlayer || !fn_ShowEntity_get_Position) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (updateStatusLabel) updateStatusLabel.text = @"Update: No Local Player";
                if (enemyCountLabel) enemyCountLabel.text = @"Enemies Detected: 0";
                ClearAllESPViews();
            });
            return;
        }

        selfPos = fn_ShowEntity_get_Position(localPlayer);
        g_selfPos = selfPos;

        // Process Data
        ProcessPlayers(localPlayer, enemies, allEntities);
        if (showMonstersHP || showESPMonsterIcons) {
            ProcessMonsters(monsters);
        }

        // Check if match ended
        if (CheckMatchEnd(enemies)) {
            playerTrackMap.clear();
			currentMatchHeroColors.clear();
            g_enemies.clear();
            dispatch_async(dispatch_get_main_queue(), ^{
                if (updateStatusLabel) updateStatusLabel.text = @"Match Ended - ESP Cleared";
                if (enemyCountLabel) enemyCountLabel.text = @"Enemies Detected: 0";
                ClearAllESPViews();
            });
            return;
        }

        g_enemies = enemies;

        // Update UI & ESP Views
        dispatch_async(dispatch_get_main_queue(), ^{
            // Set Resolution Once
            if (!g_resolutionSet && (showESPLine2 || showESPBoxes || showESPIcons || showESPHealth || 
                                    showAllEntityHP || showMonstersHP || showESPMonsterIcons)) {
                UIWindow* mainWindow = [UIApplication sharedApplication].windows.firstObject;
                if (mainWindow) {
                    CGRect bounds = mainWindow.bounds;
                    g_screenScale = [UIScreen mainScreen].scale;
                    int pw = (int)(bounds.size.width * g_screenScale);
                    int ph = (int)(bounds.size.height * g_screenScale);
                    if (Screen_SetResolution) Screen_SetResolution(pw, ph, true);
                    g_resolutionSet = true;
                }
            }

            if (enemies.empty() && allEntities.empty() && monsters.empty()) {
                if (updateStatusLabel) updateStatusLabel.text = @"Update: No Enemies";
                if (enemyCountLabel) enemyCountLabel.text = @"Enemies Detected: 0";
                ClearAllESPViews();
            } else {
                if (espLine2View && showESPLine2) [espLine2View updatePlayer:selfPos enemies:enemies];
                if (espBoxView && showESPBoxes) [espBoxView updateEnemies:enemies];
                
                if (espIconView) {
                    if (showESPIcons) [espIconView updateEnemies:enemies];
                    else [espIconView updateEnemies:{}];
                    
                    if (showESPMonsterIcons) [espIconView updateMonsters:monsters];
                    else [espIconView updateMonsters:{}];
                }

                if (espHealthView) {
                    if (showESPHealth) [espHealthView updateEnemies:enemies];
                    if (showAllEntityHP) [espHealthView updateAllEntities:allEntities];
                    if (showMonstersHP) [espHealthView updateMonsters:monsters];
                }

                if (enemyCountLabel) enemyCountLabel.text = [NSString stringWithFormat:@"Enemies Detected: %lu", (unsigned long)enemies.size()];
                if (updateStatusLabel) updateStatusLabel.text = @"Update: OK";
            }
        });
    }
    @catch (NSException *e) {
        NSLog(@"[UpdateESPData] Exception: %@", e.reason);
        g_enemies.clear();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (updateStatusLabel) updateStatusLabel.text = @"Update: Exception";
            ClearAllESPViews();
        });
    }
}

// Hook wrapper - النسخة المحسنة
static void (*orig_Update)(void *instance) = NULL;
static void Hooked_Update(void *instance) {
    if (instance) {
        BattleManager = instance;
    } else if (BattleManager != NULL) {
        // المباراة خلصت
        BattleManager = NULL;
		currentMatchHeroColors.clear();
        g_enemies.clear();
        playerTrackMap.clear();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (updateStatusLabel) updateStatusLabel.text = @"Match Ended";
            if (enemyCountLabel) enemyCountLabel.text = @"Enemies Detected: 0";
            ClearAllESPViews();
        });
    }

    if (orig_Update) orig_Update(instance);

    updateCounter++;
    if (updateCounter % updateInterval != 0) return;

    UpdateESPData();
}

// Hooks
%hook UnityAppController
- (void)applicationDidBecomeActive:(id)arg0 {
    %orig;
    static bool inited = false;
    if (inited) return;
    if (!OpenUnityFrameworkIfNeeded()) return;
    Il2CppAttach("UnityFramework");
    InitializeImageCache(); // Initialize image cache
    void *updateMethod = Il2CppGetMethodOffset("Assembly-CSharp.dll", "", "BattleManager", "Update", 0);
    if (!updateMethod) {
        updateMethod = Il2CppGetMethodOffset("Assembly-CSharp.dll", "", "LogicBattleManager", "Update", 0);
    }
    if (updateMethod) {
        MSHookFunction(updateMethod, (void*)Hooked_Update, (void**)&orig_Update);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        extern void CreateUI();
        CreateUI();
    });
    static NSTimer *clearTimer = nil;
    clearTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *timer) {
        if (g_enemies.size() > 0 && BattleManager == NULL) {
            g_enemies.clear();
            dispatch_async(dispatch_get_main_queue(), ^{
                if (updateStatusLabel) updateStatusLabel.text = @"Update: No BattleManager";
                if (enemyCountLabel) enemyCountLabel.text = @"Enemies Detected: 0";
                if (espLine2View) {
                    std::vector<EnemyData> empty;
                    [espLine2View updatePlayer:Vector3::zero() enemies:empty];
                }
                if (espBoxView) {
                    std::vector<EnemyData> empty;
                    [espBoxView updateEnemies:empty];
                }
                if (espIconView) {
                    std::vector<EnemyData> empty;
                    [espIconView updateEnemies:empty];
                    [espIconView updateMonsters:empty];
                }
                if (espHealthView) {
                    std::vector<EnemyData> emptyEnemies;
                    std::vector<AllEntityData> emptyEntities;
                    [espHealthView updateEnemies:emptyEnemies];
                    [espHealthView updateAllEntities:emptyEntities];
                    [espHealthView updateMonsters:emptyEnemies];
                }
            });
        }
    }];
    inited = true;
}

- (void)startUnity:(UIApplication *)application {
    %orig;
}
%end