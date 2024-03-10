let { Uint, TaggedUnion, FixedArray, Void, .. } = import "zig.ncl" in

let rec hid_keyboard_pattern = {
    Necessity = [| 'unwanted, 'required, '"optional" |],

    ModifierPattern = TaggedUnion
        [| 'either, 'xor, 'independent |]
        (match {
            'either => Void,
            'xor => Void,
            'independent => {
                left | Necessity | default = 'unwanted,
                right | Necessity | default = 'unwanted,
            },
        }),

    CodePattern = TaggedUnion
        [| 'any, 'exact, 'range |]
        (match {
            'any => Necessity,
            'exact => Uint 8,
            'range => { from | Uint 8, to | Uint 8 },
        }),
    
    HidKeyboardPattern = {
        mods | FixedArray 4 ModifierPattern,
        code | CodePattern,
    },
    toModifierPattern = fun str =>
        std.string.lowercase str
        |> std.string.replace "-" " "
        |> std.string.split " "
        |> std.array.filter (fun s => s != "")
        |> std.array.map (fun tok => {
            token = tok,
            side =
                let fc = std.array.first (std.string.characters tok) in
                if fc == "l" then
                    'left
                else if fc == "r" then
                    'right
                else
                    'both,
            req =
                let lc = std.array.last (std.string.characters tok) in
                if lc == "?" then
                    '"optional"
                else if lc == "^" then
                    'xor
                else
                    'required,
        })
        |> std.array.map (fun parsed => parsed & {
            mod =
                let from = if parsed.side == 'both then 0 else 1 in
                let to = (std.string.length parsed.token) - (if parsed.req == 'required then 0 else 1) in
                let name = std.string.substring from to parsed.token in

                if std.array.elem name ["ctrl", "shift", "alt", "gui"] then
                    name
                else
                    std.fail_with "Invalid modifier name `%{name}`",
            pattern =
                if parsed.side == 'both then
                    if parsed.req == '"optional" then
                        { left = '"optional", right = '"optional" }
                    else if parsed.req == 'xor then
                        'xor
                    else
                        'either
                else
                    let side = std.to_string parsed.side in
                    if parsed.req == '"optional" then
                        { "%{side}" = '"optional" }
                    else if parsed.req == 'xor then
                        std.fail_with "Single-sided mod pattern cannot be a xor."
                    else
                        { "%{side}" = 'required }
        })
        |> (
            let mod_pattern = ({
                tag | default = 'independent,
                data | {
                    left | default = 'unwanted,
                    right | default = 'unwanted,
                } | default = {}
            } | ModifierPattern) in

            let ModifierPatternWrapped = {
                ctrl | ModifierPattern | default = mod_pattern,
                shift | ModifierPattern | default = mod_pattern,
                alt | ModifierPattern | default = mod_pattern,
                gui | ModifierPattern | default = mod_pattern,
            } in

            let fold_fn = fun mods parsed => (mods & {
                "%{std.to_string parsed.mod}" =
                    if (parsed.pattern == 'either || parsed.pattern == 'xor) then
                        { tag = parsed.pattern, data = {} }
                    else
                        { tag = 'independent,  data = parsed.pattern } 
            }) | ModifierPatternWrapped in

            std.array.fold_left fold_fn ({} | ModifierPatternWrapped)
        ),

    toCodePattern = fun e =>
        if std.is_record e then
            { tag = 'exact, data = e.key_code }
        else if std.is_array e then
            let len = std.array.length e in
            if len == 0 then
                { tag = 'any, data = 'unwanted }
            else if len == 1 then
                { tag = 'exact, data = (std.array.first e).key_code }
            else if len == 2 then
                let a = (std.array.first e).key_code in
                let b = (std.array.last e).key_code in
                {
                    tag = 'range,
                    data.from = std.number.min a b,
                    data.to = std.number.max a b,
                }
            else
                std.fail_with "Code pattern array can only be of length 2 at most."
        else if std.is_string e then
            let s = std.string.trim e in
            if s == "?" then
                { tag = 'any, data = '"optional" }
            else if s == "!" then
                { tag = 'any, data = 'required }
            else
                std.fail_with "Unknown string for code pattern."
        else
            std.fail_with "Unknown value for code pattern.",

    toHidKeyboardPattern = fun str e => ({
        mods = let p = toModifierPattern str in
            { array = [p.ctrl, p.shift, p.alt, p.gui] },
        code = toCodePattern e,
    } | HidKeyboardPattern),
} in

{
    toHidKeyboardPattern = hid_keyboard_pattern.toHidKeyboardPattern,
    HidKeyboardPattern = hid_keyboard_pattern.HidKeyboardPattern,
}
