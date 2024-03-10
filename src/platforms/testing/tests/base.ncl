let imports = {
    keymap = import "kirei/ncl/keymap.ncl",
    lib = import "kirei/ncl/lib.ncl",
    zig = import "kirei/ncl/zig.ncl",
    utils = import "kirei/ncl/utils.ncl",
} in

let Uint = imports.zig.Uint in

let TestStep = imports.zig.TaggedUnion
    [| 'press, 'release, 'wait |]
    (match {
        'press => Uint 8,
        'release => Uint 8,
        'wait => Uint 8,
    })
in

let HidReport = {
    mods | Uint 8,
    codes | Array (std.contract.Sequence [ Uint 8, std.number.PosNat ]),
} in

let Test = {
    name | String,
    steps | Array TestStep,
    expected | Array HidReport,
} in

{
    TestSuite = {
        key_map | imports.keymap.KeyMap,
        tests | Array Test,
    },
    "%{"imports"}" = imports,
    step = let rec step' = {
        press = fun i => [{ tag = 'press, data = i }],
        release = fun i => [{ tag = 'release, data = i }],
        wait = fun ms => [{ tag = 'wait, data = ms }],
        tap = fun i => (press i) @ (release i),
        tap-ms = fun i ms => (press i) @ (wait ms) @ (release i),
        repress = fun i => (release i) @ (press i),
    } in step',
    codes = {
        mod = {
            lctl = 1,
            lsft = 2,
            lalt = 4,
            lgui = 8,
            rctl = 16,
            rsft = 32,
            ralt = 64,
            rgui = 128,
        },
        kc = (import "kirei/ncl/codes.ncl")
            |> std.array.slice 0 160 # 0x00 (incl) - 0xA0 (excl) 
            |> imports.utils.array.enumerate
            |> std.array.flat_map (fun {index, value} => std.array.map (fun name => { field = name, value = index }) value)
            |> std.record.from_array,
    },
    report = fun mods' codes' => {
        mods = mods',
        codes = codes', 
    },
    toKeyMap = fun keys => {
        key = keys
            |> imports.utils.array.enumerate
            |> std.array.map (fun {index, value} => { field = std.array.first value, "%{"value"}" = index })
            |> std.record.from_array,
        km = std.array.map (fun k => std.array.last k) keys,
    },
}
