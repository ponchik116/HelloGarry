# Garry's Neighbor v1.0.0

- Исправлена установка под актуальную базовую структуру UE4SS: `<Win64>\Mods`.
- Добавлена поддержка старого central-layout UE4SS, если существует `<Win64>\ue4ss\UE4SS.dll`.
- Добавлен uninstall.
- Усилена обработка ошибок Lua.
- Добавлена попытка `SetStaticMesh` с fallback на свойство `StaticMesh`.
- Добавлен `mod.json` с feature list.
