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

{
    Test = {
        key_map | imports.keymap.KeyMap,
        steps | Array TestStep,
        expected | String,
    },
    "%{"imports"}" = imports,
    step = {
        press = fun i => { tag = 'press, data = i },
        release = fun i => { tag = 'release, data = i },
        wait = fun ms => { tag = 'wait, data = ms },
    },
}
