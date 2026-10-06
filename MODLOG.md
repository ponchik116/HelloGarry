# Garry's Neighbor — MODLOG

## Source/idea
Host: Hello Neighbor
Guest/inspiration: Garry's Mod
Goal: add a real GMod-style sandbox mechanic layer inside the host game without redistributing retail game files.

## Route
UE4SS Lua loader route. UE4SS exposes keybinds, Unreal object lookup, world spawning, object properties and actor transforms.

## First vertical slice
- Spawn Engine BasicShapes: Cube, Sphere, Cylinder.
- Manipulate the spawned actors with keyboard.
- Delete one/all spawned actors.
- Toggle sandbox mode.

## Verification status
Static code package created and packaged.
Runtime verification in the user's installed Hello Neighbor could not be performed in this environment because the game is not exposed to the build container.

## Next verification
Launch Hello Neighbor with UE4SS, load a playable level, press H, then 1/2/3. If the game reports a missing class or mesh path, capture the UE4SS.log and adjust the route using the real game's reflection names.

## Publishing status
Not published. Melty's authenticated creator API is not exposed as a callable tool in this environment, so no claim of publication is made.
