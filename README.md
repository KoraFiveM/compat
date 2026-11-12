# PolyZone compatibility wrapper

This is kora_lib's optional PolyZone 2.6.2 compatibility wrapper. New kora_lib
resources should use `Kora.zones` directly.

![PolyZone around the prison](https://i.imgur.com/InKNaoL.jpg)

## Install only for a legacy manifest import

Keep this resource's folder name exactly `PolyZone` and start it only when an
installed legacy resource imports an `@PolyZone/...` file in its manifest. It
must start after `kora_lib` and before that importing resource:

```cfg
ensure kora_lib
ensure PolyZone # only for @PolyZone/... imports
```

Do not add it to a default configuration pre-emptively. The wrapper exists
because FiveM manifest imports require a real, started resource with the exact
name; kora_lib's `provide` compatibility identity cannot satisfy them.

## Using PolyZone in a Script

In order to use PolyZone in your script, you must _at least_ include PolyZone's client.lua directly in your __resource.lua or fxmanifest.lua. You can do that by using FiveM's @ syntax for importing resource files:

```lua
client_scripts {
    '@PolyZone/client.lua',
    'your_scripts_client.lua',
}
```

This will allow you to create PolyZones in your script, but will not import other zones, such as CircleZone, BoxZone, etc. All the other zones are extra, and require their own explicit imports. Here is a `client_scripts` value that will include all the zones. Note the relative order of these imports, as the ordering is necessary! Many zones rely on each other, for example EntityZone inherits from BoxZone, and all zones inherit from PolyZone (client.lua).

```lua
client_scripts {
  '@PolyZone/client.lua',
  '@PolyZone/BoxZone.lua',
  '@PolyZone/EntityZone.lua',
  '@PolyZone/CircleZone.lua',
  '@PolyZone/ComboZone.lua',
  'your_scripts_client.lua'
}
```

## Documentation
For additional information on how to use PolyZone, please take a look at the [wiki](https://github.com/mkafrin/PolyZone/wiki)

## kora_lib compatibility

This optional wrapper maps the imported PolyZone APIs onto kora_lib's shared zone
engine. Keep the manifest import order above, ensure `kora_lib` before `PolyZone`,
and only start this resource when a legacy script imports `@PolyZone/...`.

### Compatibility target

The wrapper targets PolyZone 2.6.2's public client API: PolyZone, BoxZone,
CircleZone, EntityZone, and ComboZone constructors, lifecycle methods,
containment helpers, diagnostics, debug helpers, and legacy geometry methods.
The compatibility smoke suite checks that public method surface as well as
containment, transitions, lifecycle cleanup, and manual debug behavior.

### Verify the wrapper

From this resource directory, run `bash test/run.sh`. It is a plain Lua smoke
suite: it verifies the manifest imports and legacy API behavior without
starting `PolyZone` or adding it to a server configuration.

`destroy()`/`remove()` always stop the underlying zone; this also stops an
active `onPointInOut` poll, including one inherited by `CircleZone`.
`EntityZone` is implemented as a moving model-bounds zone, so it follows an
entity's position and rotation without rebuilding static zones every frame.
`setPaused(true)` suppresses transition callbacks and custom polling until the
zone is resumed.
`ComboZone:onPlayerInOut` reports entering or leaving the combined area, not
transitions between overlapping child zones.
`ComboZone:AddZone`, `RemoveZone`, `getZones`, and exhaustive containment use
a lightweight reference grid for static children; it does not create a second
kora_lib zone. Moving or unbounded children stay in a small fallback list, so they
remain correct as they move. Children extending beyond the fixed map grid use
that fallback too, avoiding unbounded grid allocation. BoxZone and CircleZone geometry changes refresh
only the ComboZones that contain them.
`onPointInOutExhaustive` and `onPlayerInOutExhaustive` are opt-in legacy
polling APIs; they report entered and left child zones only when membership
changes.
Custom point polling validates both callbacks and a finite non-negative wait
interval before it starts a thread, so configuration mistakes fail at the call
site.
`onPlayerInOut(callback)` uses kora_lib's shared zone grid; pass an explicit
`waitInMS` only when legacy timing is required, which starts one custom poll
for that zone. ComboZone's custom poll retains its entered/left child argument.
`ComboZone:addEvent(eventName, zoneName)` also supports PolyZone's optional
child-name filter while retaining the standard `__PolyZone__:` event route.
The server-side `PolyZone:TriggerZoneEvent` route accepts server-originated
calls only; clients cannot relay arbitrary event names or payloads to every
player. Server resources can continue to use the `TriggerZoneEvent` export.
All wrapper shapes retain PolyZone's type markers and configured `name`, so
legacy inspection and ComboZone filtering work consistently.
BoxZone honors PolyZone's three- or six-value directional `scale` and `offset`
options (including explicit `minZ`/`maxZ`) when it builds its kora_lib-backed box,
including PolyZone's original length/width axes and heading direction.
The pure legacy helpers `PolyZone.rotate()` and
`BoxZone.calculateMinAndMaxZ()` are also available for existing geometry code;
`PolyZone.rotate()` accepts finite XY tables or FiveM vectors, and BoxZone keeps
its legacy `points` and `TransformPoint()` rotation contract.
`addDebugBlip()` creates PolyZone's normal short-range debug blip and releases
it when the zone is destroyed. EntityZone blips follow their entity and stop
when that entity disappears; ComboZone
delegates one blip to each child.
The legacy `debugBlip = true` creation option is supported for every shape;
it must be a boolean, creates that one blip, and does not enable a persistent
debug renderer.
CircleZone validates finite center coordinates and radius values at creation and
through its setters; `useZ` and `debugPoly` must be booleans when supplied. A
flat CircleZone (`useZ = false`) maps to kora_lib's exact shared-grid 2D circle,
so it ignores elevation without a polygon approximation; `useZ = true` remains
a 3D sphere. Both retain PolyZone's strict radius boundary: a point exactly on
the radius is outside.
BoxZone likewise validates finite center, dimensions, heading, scale, offset,
and paired finite `minZ`/`maxZ` values (`maxZ > minZ`) before it creates or
rebuilds its kora_lib-backed geometry; directional values must leave a positive
extent on every axis.
BoxZone and CircleZone skip that backing-zone rebuild when `setCenter()` is
given the same coordinates they already have.
ComboZone accepts an empty list, but otherwise requires a dense array of
PolyZone-compatible children with `isPointInside` methods.
PolyZone requires a dense array of at least three finite 2D/3D points. Height
bands require finite `minZ` and `maxZ` together with `maxZ > minZ`; otherwise
`thickness`, when supplied, must be positive and finite.
As upstream does, a legacy PolyZone without `minZ`/`maxZ` is an XY-only
footprint and ignores elevation; the wrapper preserves that behavior in
kora_lib's shared grid without a fake tall zone.
Likewise, a legacy BoxZone without `minZ`/`maxZ` remains an XY-only rectangle;
explicit bounds retain the original vertical check.
`CircleZone:draw(forceDraw)` also keeps PolyZone's manual marker visualization
available without adding a render loop.
`PolyZone:draw(forceDraw)` and `PolyZone.drawPoly(zone, forceDraw)` retain the
legacy outline-and-wall helper for polygon and BoxZone geometry.
`ComboZone:draw(forceDraw)` delegates that manual drawing to its live children.
`ComboZone:printInfo()` preserves PolyZone's on-demand child-type summary for
debugging a combined zone.
`EntityZone:draw(forceDraw)` samples the entity's current model bounds only at
the explicit draw call; it does not create a per-frame renderer.
EntityZone validates its positive entity handle, table options, dense three- or
six-value finite `scale` and `offset` arrays, query coordinates, and optional
finite non-negative `waitInMS` before it can calculate geometry or start a
player-position poll. Its poll emits one final exit when a tracked entity
disappears, then stops; `useZ`, `debugPoly`, and `debugBlip` must be booleans
when supplied. Directional scale/offset values must leave positive horizontal
and, for `useZ = true`, vertical extents.
Entity damage callbacks are isolated from FiveM's game-event handler; a
consumer error is logged without interrupting later handlers. Destroyed entity
zones reject new damage callbacks instead of retaining an inert event handler.
`PolyZone.ensureMetatable(zone)` restores a serialized legacy zone's methods
without creating an underlying kora_lib zone or starting a poll.
PolyZones retain the usual cached `min`, `max`, `size`, `center`, `area`, and
`boundingRadius` fields, with `getBoundingBoxMin/Max/Size/Center()` accessors,
without adding work to kora_lib's zone tick.

## Troubleshooting and Support
For help troubleshooting issues you've encountered (that aren't in the FAQ), or to suggest new features, use the [issues page](https://github.com/mkafrin/PolyZone/issues). Just a reminder though, I do this in my free time and so there is no guarantee an issue will be fixed or a feature will be added. In lieu of my limited time, I will prioritize issues and bugs over features. 

## FAQ - Frequently Asked Questions
**I'm getting the error `attempt to index a nil value` when creating a zone, what's wrong?**
> Did you include all the necessary scripts in your \_\_resource.lua or fxmanifest.lua? Remember some zones require other zones, like EntityZone.lua requires BoxZone.lua and BoxZone.lua requires client.lua.

**I'm getting no errors, but I can't see my zone in the right place when I turn on debug drawing**
> If you are using them, is minZ and maxZ set correctly? Or if you are using a CircleZone with useZ=true, is your center's Z value correct? If using a PolyZone, did you manually select all your points, or use the creation script? If you did it manually, the ordering of the points could be causing issues. Are you using the correct option to enable debug drawing? For PolyZones, you can use `debugPoly` and `debugGrid`, but for other zones, `debugPoly` is the only one that works.

**Is PolyZone faster than a distance check?**
> There's a page in the wiki for that, [here](https://github.com/mkafrin/PolyZone/wiki/Is-PolyZone-faster-than-a-distance-check%3F).

## License
**Please see the LICENSE file. That file will always overrule anything mentioned in the README.md or wiki**
