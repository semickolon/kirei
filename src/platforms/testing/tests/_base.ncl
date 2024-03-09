let imports = {
    keymap = import "../../../kirei/ncl/keymap.ncl",
    lib = import "../../../kirei/ncl/lib.ncl",
    zig = import "../../../kirei/ncl/zig.ncl",
} in

let TestStep = imports.zig.TaggedUnion
    [| 'press, 'release, 'wait |]
    (match {
        'press => std.number.Nat,
        'release => std.number.Nat,
        'wait => std.number.Nat,
    })
in

let HidEvent = imports.zig.TaggedUnion
    [| 'pressed, 'released |]
    (match {
        'pressed => std.number.PosNat,
        'released => std.number.PosNat,
    })
in

{
    Test = {
        key_map | imports.keymap.KeyMap,
        steps | Array TestStep,
        expected | Array HidEvent,
    },
    "%{"imports"}" = imports,
    step = {
        press = fun i => { tag = 'press, data = i },
        release = fun i => { tag = 'release, data = i },
        wait = fun ms => { tag = 'wait, data = ms },
    },
    event = {
        pressed = fun c => { tag = 'pressed, data = c },
        released = fun c => { tag = 'released, data = c },
    }
}
