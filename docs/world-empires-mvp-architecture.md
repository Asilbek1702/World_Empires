# WORLD EMPIRES — MVP Architecture Specification

**Движок:** Godot 4 (GDScript + C# для тяжёлых расчётов)
**Платформа:** PC, Windows/Linux
**Режим:** Single-player
**Цель документа:** зафиксировать техническую архитектуру вертикального среза, на котором дальше наращиваются остальные системы из полного ТЗ.

---

## 1. Цель MVP

Вертикальный срез, в котором игрок может:

1. Выбрать государство на старте.
2. Управлять регионами, городами, экономикой, армией.
3. Проходить ходы (Season Tick).
4. AI-государства действуют параллельно.
5. Начать войну, провести тактическое сражение, захватить регион.
6. Сохранить и загрузить игру без потери состояния.
7. Дойти до победы/поражения.

Всё вне этого списка — не MVP.

### Явно исключено из MVP
- Авиация
- Полноценный флот (боевые операции, адмиралы, ПЛО)
- Разведка / Fog of War (кроме упрощённой видимости)
- Колонизация
- Исторические события / альтернативная история
- Революции, перевороты, внутренние конфликты
- Культура, языки, ассимиляция
- Мировая торговля, санкции, экономические блоки
- Многоуровневая дипломатия (блоки, коалиции)

Эти системы должны подключаться позже **как отдельные модули**, не требуя переписывания ядра.

---

## 2. Архитектурные принципы

1. **Data-driven.** Юниты, здания, технологии — в `.tres`/`.json`-ресурсах, не в коде.
2. **Command System.** Любое изменение мира — через команду (`Command` → `Validate` → `Execute`). Игрок и AI используют один и тот же путь.
3. **Event Bus.** Системы не знают друг о друге напрямую, общаются через события.
4. **Единый `WorldState`.** Источник истины. UI и AI только читают его и отправляют команды.
5. **Season Tick — единственный источник прогресса времени.** Нет real-time симуляции экономики/AI.
6. **Detached UI.** UI не содержит игровую логику, только подписки на события.
7. **Плагинная расширяемость модулей.** Новый модуль (Navy, AirForce, Intelligence) подключается через тот же интерфейс `IGameSystem`, не трогая существующие.

---

## 3. Модульная структура проекта

```
res://
├── core/
│   ├── game_time/          # Season Tick, календарь
│   ├── event_bus/
│   ├── command_system/
│   ├── entity_ids/
│   ├── rng/                # детерминированный RNG + seed
│   └── save_system/
│
├── world/
│   ├── map/                # регионы, соседство, геометрия
│   ├── countries/
│   ├── regions/
│   ├── cities/
│   └── population/
│
├── economy/
│   ├── budget/
│   ├── resources/
│   └── production/
│
├── technology/
│
├── military/
│   ├── units/
│   ├── armies/
│   ├── generals/
│   └── combat/             # тактический бой
│
├── diplomacy/
│
├── ai/
│   ├── strategic/
│   ├── economic/
│   ├── military/
│   └── tactical/
│
├── ui/
│   ├── map_view/
│   ├── panels/
│   └── notifications/
│
├── data/                   # .tres/.json ресурсы
│   ├── units/
│   ├── technologies/
│   ├── buildings/
│   └── countries/
│
└── tests/
```

Каждый модуль в `world/`, `economy/`, `military/`, `diplomacy/`, `ai/` реализует интерфейс:

```gdscript
class_name IGameSystem
func on_season_tick(state: WorldState) -> void: pass
func on_command(cmd: Command) -> CommandResult: pass
```

`SeasonTickManager` вызывает `on_season_tick()` на всех зарегистрированных системах в фиксированном порядке (см. раздел 6).

---

## 4. Ключевые данные (MVP-схема)

### WorldState
```
WorldState
├── game_date: GameDate {year, season, turn_number}
├── countries: Dictionary<CountryID, Country>
├── regions: Dictionary<RegionID, Region>
├── cities: Dictionary<CityID, City>
├── armies: Dictionary<ArmyID, Army>
├── diplomacy: DiplomacyGraph
└── rng_seed: int
```

### Country
```
Country
├── id: CountryID
├── name, flag, color
├── capital_region: RegionID
├── regions: Array<RegionID>
├── treasury: float
├── income / expenses (упрощённо, без сложного бюджета)
├── technology_level: Dictionary<TechCategory, int>
├── researched_technologies: Array<TechID>
├── stability: float [0-100]
├── power_score: float           # для AI и UI
└── is_player_controlled: bool
```

### Region
```
Region
├── id: RegionID
├── country_id: CountryID
├── neighbors: Array<RegionID>
├── terrain: TerrainType
├── population: int
├── cities: Array<CityID>
├── resources: Dictionary<ResourceType, float>
├── stability: float
└── military_presence: Array<ArmyID>
```

### City (упрощённая, часть 4 полного ТЗ)
```
City
├── id: CityID
├── region_id: RegionID
├── level: CityLevel            # Village..Metropolis, без деградации в MVP
├── population: int
├── industry / food / gold / manpower: float
└── garrison: int
```

### Army
```
Army
├── id: ArmyID
├── country_id: CountryID
├── units: Array<UnitStack>     # {unit_type, count, hp, experience}
├── general_id: GeneralID
├── position: RegionID
├── supply: float [0-100]       # упрощённая формула, без полной логистики
├── movement_target: RegionID
└── order: ArmyOrder            # Move / Attack / Defend
```

### General
```
General
├── id: GeneralID
├── attack, defense, tactics, logistics, command
├── experience: int
└── army_id: ArmyID
```

Полные схемы из частей 13–14 ТЗ (способности, критические удары, множественные генералы на армию) — на этапе после MVP.

---

## 5. Command System

```
Command (base class)
├── source_country: CountryID
├── timestamp: GameDate
├── validate(state) -> bool
└── execute(state) -> CommandResult
```

MVP-команды:
- `MoveArmyCommand`
- `AttackArmyCommand`
- `BuildBuildingCommand`
- `ResearchTechnologyCommand`
- `DeclareWarCommand`
- `ProposePeaceCommand`
- `SetProductionPriorityCommand`

AI генерирует те же команды, что и игрок — никакого отдельного "AI-API" для изменения мира.

---

## 6. Season Tick — порядок выполнения (MVP-версия)

```
1. ValidatePlayerActions()
2. ResolveMovement()
3. ResolveBattles()          # тактический бой, если контакт
4. ResolveSupply()           # упрощённо
5. ResolveProduction()
6. ResolvePopulation()
7. ResolveEconomy()
8. ResolveDiplomacy()
9. RunAI()
10. UpdateWorldState()
11. CheckVictoryDefeat()
12. GenerateNotifications()
13. SaveCheck()
14. NextSeason()
```

Полный пайплайн из части 3 ТЗ (Politics, Events, Intelligence, Construction отдельным этапом) добавляется по мере подключения модулей.

---

## 7. Тактический бой (MVP)

- Сетка (grid), до 20 подразделений на сторону.
- Максимум 15 ходов, затем ничья.
- Автобой и ручной бой (ручной бой можно отложить на post-MVP, оставить только автобой на первом этапе среза — **решение зависит от приоритета**, см. раздел 10).
- Формула урона: `Attack + Tech + Experience + GeneralBonus - Defense - TerrainBonus`.
- Без критических ударов, флангов, укреплений — эти детали части 14 добавляются после.

---

## 8. AI (MVP-уровень)

Только `Strategic + Economic + Military` слои, без `Tactical AI` (тактика = автобой по формуле).

```
Strategic AI:
  - оценка собственной силы vs соседей
  - выбор: расширяться / обороняться / нейтралитет

Economic AI:
  - распределение бюджета по фиксированным пропорциям профиля
  - выбор технологии по приоритету

Military AI:
  - защита столицы
  - атака слабого соседа при явном перевесе
  - отступление при потере > 50% армии
```

Разведка/Fog of War в MVP отсутствует — AI и игрок видят карту полностью. Это упрощение, которое явно нужно снять на этапе подключения `Intelligence`-модуля.

---

## 9. Сохранение/загрузка

- Формат: JSON (человекочитаемо для отладки на MVP-этапе, бинарная сериализация — оптимизация post-MVP).
- `SaveVersion` в заголовке файла с первого дня.
- Полный `WorldState` сериализуется целиком, без разделения static/dynamic data (разделение — post-MVP оптимизация, часть 4.110 ТЗ).
- rng_seed сохраняется для детерминированности.

```
SaveFile
├── save_version: int
├── game_version: string
├── world_state: WorldState (serialized)
└── metadata: {country, date, playtime}
```

---

## 10. Открытые решения (нужен твой ответ)

1. **Ручной тактический бой в MVP или только автобой?**
   Ручной бой — это отдельная сцена, grid, юнит-контроллер. Сильно увеличивает срок. Рекомендация: **автобой в MVP**, ручной — первый post-MVP модуль.
2. **Масштаб карты для MVP.** Полный мир (3000-6000 регионов) или один континент/регион для первого среза? Рекомендация: **один континент, 150-300 регионов**, 4-8 государств.
3. **GDScript vs C# для боевых расчётов.** GDScript быстрее в разработке, C# быстрее в рантайме. Для MVP-масштаба (сотни армий, не тысячи) — **чистый GDScript**, переход на C# только при доказанной просадке FPS/Season Tick.

---

## 11. Definition of Done для MVP

- [ ] Игрок выбирает государство, видит карту 150-300 регионов
- [ ] Season Tick работает, ход = сезон, AI действует
- [ ] Экономика: доход/расход, ресурсы, простое производство
- [ ] Технологии: минимальное дерево (10-15 технологий)
- [ ] Армия: создание, движение, объединение/разделение
- [ ] Автобой сражений с понятным отчётом
- [ ] Захват региона меняет владельца, границы обновляются
- [ ] Дипломатия: объявление войны, мир
- [ ] AI: минимум 4-8 государств действуют осмысленно
- [ ] Победа (контроль карты) / поражение (потеря столицы+регионов)
- [ ] Сохранение/загрузка без потери состояния
- [ ] Базовый UI: карта, панель армии, панель экономики, панель дипломатии, уведомления

---

## 12. Путь расширения после MVP

```
MVP Core
   ↓
+ Логистика (снабжение вместо упрощённой формулы)
   ↓
+ Флот (базовый — движение, транспорт)
   ↓
+ Fog of War / разведка
   ↓
+ Ручной тактический бой
   ↓
+ Авиация
   ↓
+ Расширенная дипломатия (союзы, блоки)
   ↓
+ Исторические события / альтернативная история
   ↓
+ Внутренняя политика / революции
   ↓
+ Культура / население (полная модель)
```

Каждый пункт — отдельный `IGameSystem`, подключаемый без изменения ядра `Command System` / `Event Bus` / `WorldState`.
