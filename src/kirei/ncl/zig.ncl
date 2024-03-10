let rec toIrZon = fun e =>
    if std.is_record e then
        if std.record.has_field "_tagged_union" e then
            { "%{std.to_string e.tag}" = toIrZon e.data }
        else if std.record.has_field "_fixed_array" e then
            std.array.map toIrZon e.array
        else if std.record.has_field "_ptr" e then
            { _ptr = toIrZon e.value }
        else if std.record.has_field "_void" e then
            { _void = true }
        else
            std.record.map_values toIrZon e
    else if std.is_array e then
        # All Nickel arrays are considered Zig slices
        { _slice = std.array.map toIrZon e }
    else
        e
in

let rec toZon = fun e =>
    if std.is_record e then
        if std.record.has_field "_slice" e then
            "&%{toZon e._slice}"
        else if std.record.has_field "_ptr" e then
            "&%{toZon e._ptr}"
        else if std.record.has_field "_void" e then
            "{}"
        else
            let inner = 
                std.record.to_array e
                |> std.array.map (fun {field, value} => ".%{field} = %{toZon value}")
                |> std.array.intersperse ", "
                |> std.array.fold_left (++) ""
            in
            ".{ %{inner} }"
    else if std.is_array e then
        let inner =
            std.array.map toZon e
            |> std.array.intersperse ", "
            |> std.array.fold_left (++) ""
        in
        ".{ %{inner} }"
    else if std.is_enum e then
        ".%{std.to_string e}"
    else if std.is_string e then
        "\"%{e}\""
    else
        std.to_string e
in

let rec zig = {
    Uint = fun bits =>
        std.contract.from_predicate (fun value =>
            std.is_number value
            && std.number.is_integer value
            && value >= 0
            && value < (std.number.pow 2 bits)),

    TaggedUnion = fun tag_enum match_fn => {
        _tagged_union | Bool | default = true,
        tag | tag_enum,
        data | match_fn tag,
    },

    FixedArray = fun count T => {
        _fixed_array | Bool | default = true,
        array | Array T,
        # TODO: Check count
    },

    Ptr = fun T => {
        _ptr | Bool | default = true,
        value | T,
    },

    Void = {
        _void | Bool | default = true,
    },

    zonify = fun e => toZon (toIrZon e),
} in

zig
