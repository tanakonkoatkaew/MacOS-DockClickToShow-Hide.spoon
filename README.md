# DockClickToShowHide.spoon

Click the Dock icon of the app you are **already using**, and it hides — the way
a taskbar button works on Windows. Click it again and it comes back.

macOS has no setting for this. Clicking the Dock icon of the frontmost app does
nothing at all, so the Dock is a one-way trip: it can show an app, never put it
away. This Spoon adds the missing half, and nothing else.

**Reordering Dock icons by dragging keeps working.**

---

## Requirements

- [Hammerspoon](https://www.hammerspoon.org/)
- Accessibility permission for Hammerspoon
  (System Settings → Privacy & Security → Accessibility). Without it the Spoon
  cannot read the Dock and silently does nothing.

## Install

The directory name has to be `DockClickToShowHide.spoon` — that is the name
Hammerspoon loads the Spoon by, and it is not the same as the repository name:

```sh
git clone https://github.com/tanakonkoatkaew/MacOS-DockClickToShow-Hide.spoon.git \
  ~/.hammerspoon/Spoons/DockClickToShowHide.spoon
```

Then in `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("DockClickToShowHide")
spoon.DockClickToShowHide:start()
```

Reload your Hammerspoon config, and you are done.

## Configuration

Every option has a working default. Set them before `:start()`.

```lua
hs.loadSpoon("DockClickToShowHide")

-- "hide" (default) collapses the app into its own Dock icon, keeping the
-- Dock tidy. "minimize" sends each window to the right-hand side of the
-- Dock as its own thumbnail.
spoon.DockClickToShowHide.action = "hide"

-- How far the pointer may move and still count as a click, in points.
-- Raise it if a shaky hand keeps registering as a drag. Default 6.
spoon.DockClickToShowHide.dragThreshold = 6

-- Clicks farther than this from a screen edge skip the Dock check entirely.
-- Raise it if you run a very large Dock with magnification and clicks stop
-- registering. Default 160.
spoon.DockClickToShowHide.edgeMargin = 160

spoon.DockClickToShowHide:start()
```

## API

| Method | Description |
| --- | --- |
| `:start()` | Start watching for Dock clicks |
| `:stop()` | Stop, and restore stock macOS behaviour |
| `:decide(point)` | Return `"hide"` or `"pass"` plus a reason, for a point on screen. Changes nothing, so it is safe to call while debugging |

```lua
-- Why did that click not do anything?
hs.inspect({ spoon.DockClickToShowHide:decide(hs.mouse.absolutePosition()) })
```

## What it leaves alone

The Spoon steps aside for anything that is not a plain click on the active
app's icon:

- **Dragging** to reorder or remove icons — mouse-down is never swallowed, so
  the Dock sees the whole gesture. The decision is made on mouse-up, and only
  if the pointer stayed put.
- **⌘-click** (Show in Finder), and ⌥ / ⌃ / ⇧ clicks.
- **Icons of apps that are not frontmost** — those behave normally.
- **Apps with no visible windows**, and apps that are already hidden, so the
  Dock can bring them back the usual way.

## How it works

Every left click on screen would otherwise need an accessibility hit-test to
find out what sits under the pointer, and that costs about 5 ms. The Dock is
always against a screen edge, so clicks farther away than `edgeMargin` are
dropped by a cheap bounds check first — 0.004 ms, roughly 1,400× faster — and
the hit-test only runs near an edge.

When the click does land on the frontmost app's Dock icon, the mouse-up is
swallowed. Otherwise the Dock would see a click on a freshly hidden app and
immediately bring it back.

One implementation note worth writing down: a Dock item's `AXURL` is not a
string. It arrives as an NSURL table, `{ filePath = ..., url = ... }`, so
comparing it to `app:path()` as a string silently never matches.

## Credits

Inspired by [DockClick.spoon](https://github.com/silasbur/DockClick.spoon) by
Silas Burger, which clicks the Dock icon of the active app from a hotkey. This
Spoon goes the other direction — the click puts the app away — and is a fresh
implementation.

## License

[MIT](LICENSE)

---

# ภาษาไทย

คลิกไอคอนบน Dock ของแอปที่**กำลังใช้อยู่** แล้วมันจะย่อหายไป เหมือนกดปุ่มบน
taskbar ของ Windows คลิกซ้ำอีกทีก็กลับมา

macOS ไม่มีค่าตั้งนี้ให้ คลิกไอคอนของแอปที่ active อยู่แล้วมันไม่ทำอะไรเลย
Dock เลยเป็นทางเดียว คือเรียกแอปออกมาได้อย่างเดียว เก็บกลับไม่ได้ Spoon นี้
เติมส่วนที่ขาดไป **และยังลากจัดเรียงไอคอนได้ตามปกติ**

### ต้องมีก่อน

- [Hammerspoon](https://www.hammerspoon.org/)
- เปิดสิทธิ์ Accessibility ให้ Hammerspoon (System Settings → Privacy &
  Security → Accessibility) ถ้าไม่เปิด Spoon จะอ่าน Dock ไม่ได้และเงียบสนิท

### ติดตั้ง

ชื่อโฟลเดอร์ต้องเป็น `DockClickToShowHide.spoon` เท่านั้น เพราะเป็นชื่อที่
Hammerspoon ใช้โหลด และไม่ตรงกับชื่อ repo:

```sh
git clone https://github.com/tanakonkoatkaew/MacOS-DockClickToShow-Hide.spoon.git \
  ~/.hammerspoon/Spoons/DockClickToShowHide.spoon
```

แล้วใส่ใน `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("DockClickToShowHide")
spoon.DockClickToShowHide:start()
```

### ปรับแต่ง

- `action` — `"hide"` (ค่าเริ่มต้น) ยุบเข้าไอคอนเดิมตัวเดียว Dock ไม่รก
  ส่วน `"minimize"` จะย่อทีละหน้าต่างไปกองฝั่งขวาของ Dock
- `dragThreshold` — เมาส์ขยับได้กี่ pixel ถึงยังนับว่าเป็นคลิก (ค่าเริ่มต้น 6)
  ถ้ามือสั่นแล้วมันนับเป็นลากบ่อย ให้เพิ่มค่านี้
- `edgeMargin` — คลิกที่ห่างจากขอบจอเกินค่านี้จะข้ามการตรวจ Dock ไปเลย
  (ค่าเริ่มต้น 160) ถ้าเปิด Dock ใหญ่มากพร้อม magnification แล้วคลิกไม่ติด
  ให้เพิ่มค่านี้

### สิ่งที่ Spoon นี้ไม่ยุ่งด้วย

ลากจัดเรียงไอคอน, `⌘`+คลิก (Show in Finder), `⌥` `⌃` `⇧`+คลิก,
ไอคอนของแอปที่ไม่ได้ active, แอปที่ไม่มีหน้าต่างเปิดอยู่ และแอปที่ซ่อนอยู่แล้ว
— ทั้งหมดนี้ทำงานตามปกติของ macOS
