-- Nova — reference click GUI for the ui.* layout library.
--
-- This is the whole theme. What it does NOT contain is the point: no manual row arithmetic, no second
-- copy of every widget's height, no hand-managed "did something already eat this click" flag, no
-- per-column scroll offsets, no stashing a dropdown's rect in a global to redraw it later, and no
-- hardcoded category list. Those all live once, in lib/global/ui*.lua.
--
-- Layout:
--   [rail] [ header: wordmark + search + star             ]
--          [ card    card ]  two columns of group boxes, balanced on
--          [ card    card ]  measured pixels, each column scrolling alone
--          [ card         ]

local WIN_W, WIN_H = 900, 640

local search_open = false
local search_text = ""
local SEARCH_ID = nil        -- assigned on first frame (ui.id needs the C++ hash binding)

local function skin()
    local sk = ui.skin
    sk.radius    = 14
    sk.card_head = 34
    sk.rail_w    = 54
    sk.header_h  = 48
    return sk
end

-- ── header chrome ────────────────────────────────────────────────────────────
-- Hand-painted because it is chrome, not menu content. It still plays by the rules: it hit-tests with
-- ui.clicked (clip-aware, consuming) rather than raw mouse maths.

local function draw_search_icon(x, cy, sk, active)
    local c = active and sk.col.acc or sk.col.txt_dim
    draw.circle_outline(x + 6, cy - 1, 5, c[1], c[2], c[3], 255, 1.4)
    draw.line(x + 9.5, cy + 2.5, x + 13, cy + 6, c[1], c[2], c[3], 255, 1.4)
end

local function draw_star(x, cy, sk, on)
    local c = on and sk.col.acc or sk.col.txt_dim
    local pts = {}
    for i = 0, 9 do
        local a = -math.pi * 0.5 + i * math.pi / 5
        local rr = (i % 2 == 0) and 8 or 3.6
        pts[#pts + 1] = { x + 6 + math.cos(a) * rr, cy + math.sin(a) * rr }
    end
    for i = 1, #pts do
        local a, b = pts[i], pts[(i % #pts) + 1]
        draw.line(a[1], a[2], b[1], b[2], c[1], c[2], c[3], 255, 1.4)
    end
end

local function header_right(x, y, w, h, sk)
    local cy = y + h * 0.5
    local star_x = x + w - 26
    local srch_x = star_x - 26

    -- Search: the icon toggles an inline field that occupies the header's middle. While the query is
    -- non-empty the page cards are replaced by grouped search results (see draw_menu).
    if search_open then
        local fw = 220
        local fx = srch_x - fw - 8
        local fy = y + (h - 24) * 0.5
        draw.rect(fx, fy, fx + fw, fy + 24, sk.col.field[1], sk.col.field[2], sk.col.field[3], 255, 6)
        draw.rect_outline(fx, fy, fx + fw, fy + 24, sk.col.acc[1], sk.col.acc[2], sk.col.acc[3], 255, 6, 1)

        local f = sk.font.value
        local shown, _, status = ui.text_edit(SEARCH_ID)
        if ui.focused() == SEARCH_ID then
            search_text = shown
            if status == 1 or status == 2 then
                if status == 2 then search_text = "" end
                search_open = (search_text ~= "")
            end
        end
        local disp = (search_text ~= "") and search_text or "Search…"
        local c = (search_text ~= "") and sk.col.txt or sk.col.txt_off
        ui.push_clip(fx + 4, fy, fx + fw - 4, fy + 24)
        text.draw(f, fx + 8, fy + (24 - text.height(f)) * 0.5, c[1], c[2], c[3], 255, disp)
        if ui.focused() == SEARCH_ID and math.floor(ctx.time() * 2) % 2 == 0 then
            local cw = text.width(f, string.sub(search_text, 1, ui.caret()))
            draw.line(fx + 8 + cw, fy + 4, fx + 8 + cw, fy + 20,
                      sk.col.txt[1], sk.col.txt[2], sk.col.txt[3], 255, 1)
        end
        ui.pop_clip()
        if ui.clicked(fx, fy, fx + fw, fy + 24, 0) then ui.focus(SEARCH_ID, search_text, 0) end
    end

    draw_search_icon(srch_x, cy, sk, search_open)
    if ui.clicked(srch_x - 6, cy - 11, srch_x + 18, cy + 11, 0) then
        search_open = not search_open
        if search_open then ui.focus(SEARCH_ID, search_text, 0) else ui.blur(); search_text = "" end
    end

    draw_star(star_x, cy, sk, false)
    if ui.clicked(star_x - 6, cy - 11, star_x + 18, cy + 11, 0) then
        notify.push("Nenyoo", "Favourites are not wired up in this theme yet", 0, 3.0)
    end
end

-- ── frame ────────────────────────────────────────────────────────────────────

function draw_menu()
    if not menu.is_visible() then return end
    ui.begin_frame()
    local sk = skin()
    SEARCH_ID = SEARCH_ID or ui.id("nova", "search")

    local x, y = ui.window("nova", WIN_W, WIN_H, sk)

    -- Cards come from the current page, or from the search index while a query is active. Both are
    -- just lists of nodes, so the rest of the layout does not care which.
    local cards = (search_text ~= "") and ui.cards_for_search(search_text) or ui.cards_for_page()

    local body_h = WIN_H - sk.header_h - sk.pad
    local tree = ui.row{
        gap = 0,
        weights = { sk.rail_w, 1 },          -- fixed-width rail, everything else to the content
        ui.icon_rail{ h = WIN_H },
        ui.column{
            gap = sk.gap,
            pad = 0,
            ui.header{ wordmark = "NENYOO", right = header_right },
            ui.columns{
                n = 2,
                -- Scroll state is keyed by this id, so each page remembers its own position and a new
                -- page starts at the top. No reset plumbing anywhere in the theme.
                id = ui.id("page", menu.page_id(), search_text ~= "" and "search" or ""),
                h = body_h - sk.gap,
                -- One scroll for the whole grid: the reference has a single bar at the
                -- window edge, not one per column.
                independent_scroll = false,
                table.unpack(cards),
            },
        },
    }

    ui.draw(tree, x, y, WIN_W, sk)
    ui.end_frame()
end

function handle_input()
    -- Arrows move the focus ring, Enter activates through the same path a click takes, Escape/Back
    -- go up a page. Without this the menu is mouse-only.
    ui.keyboard_nav()
end
