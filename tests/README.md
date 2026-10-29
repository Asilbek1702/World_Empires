# tests/

- `run_all.sh` запускает все тесты и проверяет результат по выводу
- `test_base.gd` общая основа тестов (`check`, `finish`)
- `unit/test_*.gd` по одному файлу на систему; один тест запускается так:

      godot --headless --path . --script res://tests/unit/test_game_date.gd
