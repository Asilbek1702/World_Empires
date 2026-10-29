# core/

Фундамент, не зависит от конкретных игровых механик.

- `game_time/` `GameDate`, `TickOrder` (13 фаз сезона), `SeasonTickManager` (autoload)
- `event_bus/` `EventBus` (autoload) и реестр имён событий `Events`
- `rng/` `GameRNG`: детерминированный генератор с seed и позицией
- `entity_ids/` типизированные ID (`region_00125`) и `IdGenerator`
- `command_system/` `Command`, `CommandBus` (autoload), `CommandResult`, `commands/`
- `save_system/` `SaveSystem` (JSON, запись через временный файл), `SaveFileFormat`
- `game_systems.gd` список систем игры (одна строка на систему)
- `json_numbers.gd`, `number_format.gd` вспомогательные функции
