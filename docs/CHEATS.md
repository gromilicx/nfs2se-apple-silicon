# Cheat guide

Activate from the main menu in **Single Race**, local or split-screen. The panel is available through F12/Fn+F12, Command+Shift+K, or the **Kodovi** menu. Activation is disabled during races and movies. Confirm submenu changes with DONE; CANCEL can restore previous settings.

Original codes set flags or unlock content; retyping does not toggle them off. The native **Ukloni efekte** action resets temporary effects, GO overrides, night/camera preparation, and active Slot selections while retaining car/track/Slot unlock availability. **Običan automobil** clears only the model overrides.

## Original typed codes

| Code | Behavior in this executable |
| --- | --- |
| `fzr2000` | Unlock FZR 2000; the native panel also selects it after an existing unlock. |
| `tombstone` | Unlock Daytona; the native panel also selects it after an existing unlock. |
| `bomber` | Unlock BFS Bomber; the native panel also selects it after an existing unlock. |
| `hollywood` | Unlock and select Monolithic Studios. |
| `pioneer` | Original engine option; activation opens the original notification. |
| `slip` | Slippery road/grip override, not slow motion. |
| `slot` | Unlock the Slot option; select it in the car menu with Arcade/Wild driving style. |
| `mad` | Recognized but no effect in this software executable; a 3Dfx-only effect. |
| `rain` | Rain regions on Proving Grounds, North Country, and Mystic Peaks. |
| `chase` | Enable the original Chase flag; detailed driving behavior was not separately observed. |
| `kcjones` | Recognized but no effect in this software executable; a 3Dfx-only effect. |
| `rushhour` | Extra traffic when race settings permit; can use a selected model override. |
| `rexhour` | T-Rex model override for players/opponents and traffic. REXRAGE is not recognized. |
| `madland` | Wooden-outhouse model override, traffic, and Pioneer; not a color effect. |
| `schoolzone` | School-bus override, traffic, and Pioneer. |
| `vip` | Limousine override, traffic, and Pioneer. |
| `roadrage` | Enable the original horn-related flag; the collision effect was not individually driven. |

`red racer` is absent from this executable. Ford Indigo is already a normal SE car.

## GO models

All 34 codes from `go18` through `go51` are accepted. They override player/opponent models for the next race. A preview may still show the ordinary car. GO alone does not add traffic; RUSHHOUR can make traffic use the same model.

| Code | Model | Asset ID |
| --- | --- | --- |
| `go18` | School bus | `SBUS` |
| `go19` | Pickup | `COMC` |
| `go20` | School bus | `SBUS` |
| `go21` | Truck | `SEMI` |
| `go22` | School bus | `SBUS` |
| `go23` | Blue Audi sedan | `QUAT` |
| `go24` | School bus | `SBUS` |
| `go25` | School bus | `SBUS` |
| `go26` | Mercedes | `MERC` |
| `go27` | Green Volkswagen | `VWFB` |
| `go28` | Grey Mazda convertible | `MIAT` |
| `go29` | School bus | `SBUS` |
| `go30` | School bus | `SBUS` |
| `go31` | Army Unimog | `ARMY` |
| `go32` | School bus | `SBUS` |
| `go33` | Snow truck | `SNOW` |
| `go34` | Monolithic tram | `mono` |
| `go35` | Limousine | `limo` |
| `go36` | Grey Mazda convertible | `MIAT` |
| `go37` | School bus | `SBUS` |
| `go38` | School bus | `SBUS` |
| `go39` | School bus | `SBUS` |
| `go40` | Crate | `CRAT` |
| `go41` | Hand cart | `CART` |
| `go42` | Wooden outhouse | `OUTH` |
| `go43` | Tyrannosaurus Rex | `TREX` |
| `go44` | Wild West wagon | `WAGO` |
| `go45` | Souvenir stand1 | `SOU1` |
| `go46` | Souvenir stand2 | `SOU2` |
| `go47` | News stand | `SOU3` |
| `go48` | Log | `LOG` |
| `go49` | Box | `BOX` |
| `go50` | Beer box | `BEER` |
| `go51` | Rock | `RUIN` |

Several numbers share the school-bus model, and GO28/GO36 share a convertible asset. Descriptive labels for objects are based on the supplied guide and original asset abbreviations; every appearance was not visually compared.

## Special procedures

| Entry | Support and conditions |
| --- | --- |
| Night | The native panel temporarily holds N during the original loading routine. Remains prepared for subsequent supported races until reset or app exit. |
| Nine cameras | The panel temporarily holds C+B+Right Shift around the original camera setup. The claimed six-press counter is absent from that routine. Remains prepared until reset or exit. |
| Heavier car | The original mass check compares a driver name with exactly uppercase `SIL SPD`, including a space, then multiplies mass by four. Full record-entry formatting and persistence were not run-tested. This is not a typed main-menu code. |
| Barrier secret | Original collision logic exists on Mediterraneo/Mystic Peaks with horn, reversing, object, speed, and track-region conditions. It is not universal no-collision mode. The guide's exact speeds and McLaren-only claim were not confirmed. Instructions only; no automatic activation. |
| H turbo | The screenshot claim remains unverified. No automatic turbo button is provided. |

## Verification limits

186 isolated checks cover original acceptance/state changes, native queue/reset behavior, and original night/camera preparation. PIONEER was recognizer-only in the headless test and its actual dialog/activation was subsequently checked in-game. FZR 2000, reset, and a night race were also checked in-game. This does not establish visual or physical validation of every effect. See [the verification record](VERIFICATION.md) and JSON audits for exact evidence.
