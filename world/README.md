# world/

- `world_state.gd` WorldState (autoload): дата, seed, регионы, страны, города, армии
- `world_builder.gd` собирает новый мир из данных; `world_integrity.gd` правила целостности
- `map/` `Region`, загрузка и запросы карты, границы, камера, отрисовка
- `countries/` `Country`, загрузка стран, отрисовка границ стран
- `cities/` `City`, загрузка городов
- `population/` модель и система роста населения
