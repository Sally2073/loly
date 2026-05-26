#ifndef HEADER_H
#define HEADER_H

#include <vector>
#include <string>
#include <UIKit/UIKit.h>
#import "hidey.h"

// IL2CPP Structure Definitions
struct Il2CppObject {
    void* klass;
    void* monitor;
};

struct Il2CppArrayBounds {
    uintptr_t length;
    int32_t lower_bound;
};

struct Il2CppArray {
    Il2CppObject obj;
    Il2CppArrayBounds *bounds;
    uintptr_t max_length;
    void* _vector[1];
};

struct Il2CppList {
    Il2CppObject obj;
    Il2CppArray* _items;
    int32_t _size;
    int32_t _version;
    void* syncRoot;
};

struct Il2CppDictionaryEntry {
    int32_t hashCode;
    int32_t next;
    Il2CppObject* key;
    Il2CppObject* value;
};

struct Il2CppDictionary {
    Il2CppObject obj;
    Il2CppArray* buckets;
    Il2CppArray* entries;
    int32_t count;
    int32_t version;
    int32_t freeList;
    int32_t freeCount;
    Il2CppObject* comparer;
    Il2CppObject* keys;
    Il2CppObject* values;
    Il2CppObject* syncRoot;
};

struct Vector3 {
    float x, y, z;
    Vector3(float X=0, float Y=0, float Z=0) : x(X), y(Y), z(Z) {}
    static Vector3 zero() { return Vector3(); }
Vector3 operator-(const Vector3& other) const {
        return Vector3(x - other.x, y - other.y, z - other.z);
    }
    
    float magnitude() const {
        return sqrtf(x*x + y*y + z*z);
    }
};

struct EnemyData {
    void* showEntity;
    Vector3 position;
    NSString* heroName;
    NSString* roleName;
    int32_t hp;
    int32_t hpMax;
    int32_t monsterId;
};

struct AllEntityData {
    void* showEntity;
    Vector3 position;
    NSString* heroName;
    NSString* roleName;
    int32_t hp;
    int32_t hpMax;
};

// ====================== ESPLine2View مع ألوان + مسافات ======================
@interface ESPLine2View : UIView {
@private
    Vector3 _playerPosition;
    std::vector<EnemyData> _enemies;
}
- (void)updatePlayer:(Vector3)pos enemies:(const std::vector<EnemyData>&)enemies;
@end
// ===========================================================================

@interface ESPBoxView : UIView {
@private
    std::vector<EnemyData> enemies;
}
- (void)updateEnemies:(const std::vector<EnemyData>&)enemies;
@end

@interface ESPIconView : UIView
@property (nonatomic, strong) NSMutableArray<UIImageView*> *playerIconPool;
@property (nonatomic, strong) NSMutableArray<UIImageView*> *monsterIconPool;


- (void)updateEnemies:(const std::vector<EnemyData>&)enemies;
- (void)updateMonsters:(const std::vector<EnemyData>&)monsters;

@end

@interface ESPHealthView : UIView


- (void)updateEnemies:(const std::vector<EnemyData>&)enemies;
- (void)updateAllEntities:(const std::vector<AllEntityData>&)allEntities;
- (void)updateMonsters:(const std::vector<EnemyData>&)monsters;


@end
// Global UI elements
extern UIScrollView* menuView;
extern UIButton* floatingButton;
extern UILabel* enemyCountLabel;
extern UILabel* updateStatusLabel;
extern UILabel* fovStatusLabel;
extern UILabel* espLine2StatusLabel;
extern UILabel* espBoxStatusLabel;
extern UILabel* espIconStatusLabel;
extern UILabel* espHealthStatusLabel;
extern UILabel* espAllEntityHPStatusLabel;
extern UILabel* espMonstersHPStatusLabel;
extern UILabel* espMonsterIconStatusLabel;
extern UILabel* espAllStatusLabel;
extern UIView* generalView;
extern UIView* miniMapView;
extern UIView* fovView;
extern UIView* espSpeedView;
extern UIView* titleBar;
extern ESPLine2View* espLine2View;
extern ESPBoxView* espBoxView;
extern ESPIconView* espIconView;
extern ESPHealthView* espHealthView;

// Global variables
extern CGFloat g_screenScale;
extern bool g_resolutionSet;
extern bool showESPLine2;
extern bool showESPBoxes;
extern bool showESPIcons;
extern bool showESPHealth;
extern bool showAllEntityHP;
extern bool showMonstersHP;
extern bool showESPMonsterIcons;
extern bool showAllESP;
extern int updateInterval;
extern Vector3 g_selfPos;
extern std::vector<EnemyData> g_enemies;
extern void* BattleManager;
extern size_t off_m_ShowPlayers;
extern const float fovOptions[];

// Function declarations
extern bool safe_read_ptr(void *src, void **out);
extern void TryFindBattleManagerSingleton();
extern void SetFOV(float fovValue);
extern void ResetFOV();

#endif