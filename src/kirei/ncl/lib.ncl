let utils = import "utils.ncl" in

let rec lib = {
    lit = fun value => {
        tag = 'literal,
        data = value,
    },

    switch = fun branches' fallback' => {
        tag = 'swt,
        data = {
            branches = branches',
            fallback = fallback',
        },
    },

    case = fun condition' value' => {
        condition = condition',
        value = value',
    },

    and = fun conditions => {
        tag = 'logical_and,
        data = conditions,
    },

    or = fun conditions => {
        tag = 'logical_or,
        data = conditions,
    },

    not = fun condition => {
        tag = 'logical_not,
        data.value = condition,
    },

    query = fun tag' data' => {
        tag = 'query,
        data = { tag = tag', data = data' },
    },

    is-key-code-pressed = fun key_code =>
        let kc = if std.is_record key_code then key_code.key_code else key_code in
        query 'is_key_code_pressed kc,
    
    is-key-pressed = fun key_index => query 'is_key_pressed key_index,

    key-press = fun kg => {
        tag = 'key_press,
        data = { key_group = kg },
    },

    key-toggle = fun kg => {
        tag = 'key_toggle,
        data = { key_group = kg },
    },

    kc = (import "codes.ncl")
        |> utils.array.enumerate
        |> std.array.flat_map (fun {index, value} => std.array.map (fun name => { field = name, value = { key_code = index } }) value)
        |> std.record.from_array,

    mod-base = fun name side' retention anti => {
        mods."%{std.to_string name}" = {
            side = side',
            props.retention = retention,
            props.anti = anti,
        },
    },

    mod =           fun name side => mod-base name side 'normal false,
    mod-anti =      fun name side => mod-base name side 'normal true,
    mod-weak =      fun name side => mod-base name side 'weak false,
    mod-weak-anti = fun name side => mod-base name side 'weak true,
}
in

lib
