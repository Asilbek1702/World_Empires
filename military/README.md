# military/

Юниты, армии, генералы (Итерация 12). Только данные и команды, без движения и боя.

- `units/` `UnitType` и `UnitCatalog` (data/units/units.json), `Unit`: нанятый юнит
- `armies/` `Army`: до 20 юнитов в одном регионе, один генерал
- `generals/` `General` и `GeneralFactory` (4 стартовых генерала на страну, без RNG)
- `military_rules.gd` правила найма, создания армии и назначения генерала

Команды (`core/command_system/commands/`): `RecruitUnitCommand`, `CreateArmyCommand`,
`AssignGeneralCommand`. Найм платит золото и manpower сразу. Manpower теперь запас
страны (`Country.manpower`): каждый сезон к нему добавляется выработка регионов.
Id юнитов и армий выдаёт `WorldState.id_generator`, его счётчики сохраняются.
Содержание армий (расходы) и поле `Army.supply` пока заглушки: движение в Итерации 13, бой в 15.
