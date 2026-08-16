--- === DockClickToShowHide ===
---
--- Click the Dock icon of the app you are already using, and it hides —
--- like clicking a taskbar button on Windows. Click it again and macOS
--- brings it back, which it already does natively.
---
--- macOS has no built-in setting for this: clicking the Dock icon of the
--- frontmost app does nothing. This Spoon adds the missing half.
---
--- Dragging Dock icons to reorder them keeps working: the Spoon lets every
--- mouse-down through and only decides on mouse-up, after checking whether
--- the pointer actually moved.
---
--- Download: [https://github.com/tanakonkoatkaew/MacOS-DockClickToShow-Hide.spoon](https://github.com/tanakonkoatkaew/MacOS-DockClickToShow-Hide.spoon)

local ax = require("hs.axuielement")

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "DockClickToShowHide"
obj.version = "1.0.0"
obj.author = "tanakonkoatkaew"
obj.homepage = "https://github.com/tanakonkoatkaew/MacOS-DockClickToShow-Hide.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- DockClickToShowHide.action
--- Variable
--- What to do when you click the Dock icon of the active app.
---
--- * `"hide"` (default) — hide the whole app. It collapses into its own Dock
---   icon, so the Dock stays tidy. Closest match to the Windows taskbar.
--- * `"minimize"` — minimize each visible window instead. Every window gets
---   its own thumbnail on the right-hand side of the Dock.
obj.action = "hide"

--- DockClickToShowHide.dragThreshold
--- Variable
--- How far the pointer may travel (in points) between mouse-down and mouse-up
--- and still count as a click rather than a drag. Raise it if a shaky hand
--- stops icons from hiding. Default 6.
obj.dragThreshold = 6

--- DockClickToShowHide.edgeMargin
--- Variable
--- Clicks farther than this (in points) from a screen edge skip the
--- accessibility hit-test entirely, since the Dock always sits against an
--- edge. This keeps the Spoon off the hot path of every other click on
--- screen: the hit-test costs ~5 ms, the edge check ~0.004 ms.
---
--- Raise it if you run the Dock at a very large size with magnification and
--- clicks stop registering. Default 160.
obj.edgeMargin = 160

-- Candidate click: set on mouse-down, confirmed or discarded on mouse-up.
local pending = nil
local screenFrames = {}

local function refreshScreens()
	screenFrames = {}
	for _, scr in ipairs(hs.screen.allScreens()) do
		table.insert(screenFrames, scr:fullFrame())
	end
end

-- Is the point close enough to a screen edge to plausibly be the Dock?
local function nearScreenEdge(pt)
	for _, f in ipairs(screenFrames) do
		if pt.x >= f.x and pt.x <= f.x + f.w and pt.y >= f.y and pt.y <= f.y + f.h then
			local m = obj.edgeMargin
			return pt.y > f.y + f.h - m or pt.x < f.x + m or pt.x > f.x + f.w - m
		end
	end
	return true -- unknown screen: fall through to the full check
end

-- A Dock item's AXURL comes back as an NSURL table, not a string:
-- { filePath = "/Applications/Safari.app", url = "file:///Applications/Safari.app/" }
local function dockItemPath(el)
	local ok, url = pcall(function() return el.AXURL end)
	if not ok or type(url) ~= "table" then return nil end
	if url.filePath then return url.filePath end
	local s = tostring(url.url or ""):match("^file://(.*)")
	if not s then return nil end
	s = s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
	return (s:gsub("/+$", ""))
end

-- Walk up a few levels: the hit-test may land on a child of the Dock item.
local function dockItemAt(point)
	local ok, el = pcall(ax.systemElementAtPosition, point)
	if not ok or not el then return nil end
	for _ = 1, 4 do
		local okr, sub = pcall(function() return el.AXSubrole end)
		if okr and sub == "AXApplicationDockItem" then return el end
		local okp, parent = pcall(function() return el.AXParent end)
		if not okp or not parent then return nil end
		el = parent
	end
	return nil
end

--- DockClickToShowHide:decide(point) -> string, string, string
--- Method
--- Works out whether a click at `point` should hide the active app. Pure —
--- it changes nothing, so it is safe to call when debugging.
---
--- Parameters:
---  * point - A table with `x` and `y` in screen coordinates
---
--- Returns:
---  * `"hide"` or `"pass"`
---  * A short reason, handy in the Hammerspoon console
---  * The name of the frontmost app, or nil
function obj:decide(point)
	if not nearScreenEdge(point) then return "pass", "too far from any screen edge", nil end

	local item = dockItemAt(point)
	if not item then return "pass", "not on a Dock item", nil end

	local front = hs.application.frontmostApplication()
	if not front then return "pass", "no frontmost app", nil end

	if dockItemPath(item) ~= front:path() then
		return "pass", "a different app than the active one", front:name()
	end
	if front:isHidden() then return "pass", "already hidden", front:name() end
	if #front:visibleWindows() == 0 then return "pass", "no visible windows to hide", front:name() end

	return "hide", "match", front:name()
end

-- Modifier-clicks belong to the Dock: cmd-click reveals in Finder, and the
-- others have their own meanings. Never swallow those.
local function hasModifier(e)
	local fl = e:getFlags()
	return fl.cmd or fl.alt or fl.ctrl or fl.shift
end

local function movedTooFar(loc, origin)
	local dx, dy = loc.x - origin.x, loc.y - origin.y
	return (dx * dx + dy * dy) > (obj.dragThreshold * obj.dragThreshold)
end

local function performAction(app)
	if obj.action == "minimize" then
		for _, w in ipairs(app:visibleWindows()) do
			if w:isStandard() then w:minimize() end
		end
	else
		app:hide()
	end
end

local function onEvent(e)
	local t = e:getType()
	local loc = e:location()
	local types = hs.eventtap.event.types

	if t == types.leftMouseDown then
		-- Remember the candidate but let the event through, so dragging a Dock
		-- icon to reorder it still works.
		pending = nil
		if hasModifier(e) then return false end
		local action = obj:decide(loc)
		if action == "hide" then
			local front = hs.application.frontmostApplication()
			pending = { app = front, x = loc.x, y = loc.y }
		end
		return false
	end

	if t == types.leftMouseDragged then
		if pending and movedTooFar(loc, pending) then pending = nil end
		return false
	end

	if t == types.leftMouseUp then
		local cand = pending
		pending = nil
		if not cand then return false end
		if movedTooFar(loc, cand) then return false end
		if hasModifier(e) then return false end

		-- The app may have quit while the button was held down.
		local ok, unavailable = pcall(function()
			return not cand.app:isRunning() or cand.app:isHidden()
		end)
		if not ok or unavailable then return false end
		if not pcall(performAction, cand.app) then return false end

		-- Swallow the mouse-up so the Dock does not immediately reactivate it.
		return true
	end

	return false
end

-- Exposed for the test suite.
obj._onEvent = function(e) return onEvent(e) end
obj._pending = function() return pending end

--- DockClickToShowHide:init()
--- Method
--- Called by `hs.loadSpoon()`. Caches the screen frames used by the fast path.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The DockClickToShowHide object
function obj:init()
	refreshScreens()
	self.screenWatcher = hs.screen.watcher.new(refreshScreens)
	return self
end

--- DockClickToShowHide:start()
--- Method
--- Starts watching for Dock clicks.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The DockClickToShowHide object
function obj:start()
	if self.screenWatcher then self.screenWatcher:start() end
	local types = hs.eventtap.event.types
	self.tap = hs.eventtap.new(
		{ types.leftMouseDown, types.leftMouseDragged, types.leftMouseUp },
		onEvent
	):start()
	return self
end

--- DockClickToShowHide:stop()
--- Method
--- Stops watching. Dock clicks go back to their stock macOS behaviour.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The DockClickToShowHide object
function obj:stop()
	if self.tap then
		self.tap:stop()
		self.tap = nil
	end
	if self.screenWatcher then self.screenWatcher:stop() end
	pending = nil
	return self
end

return obj
