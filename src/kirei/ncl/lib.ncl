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

    is-key-pressed = fun key_index => query 'is_key_pressed key_index,

    key-press = fun kg => {
        tag = 'key_press,
        data = { key_group = kg },
    },

    kc = {
        A = { key_code = 4 },
        B = { key_code = 5 },
        C = { key_code = 6 },
        D = { key_code = 7 },
        E = { key_code = 8 },
        F = { key_code = 9 },
        G = { key_code = 10 },
        H = { key_code = 11 },
    },

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
