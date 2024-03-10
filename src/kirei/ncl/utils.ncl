let rec array' = {
      enumerate = fun arr => std.array.fold_left (fun acc e => acc @ [{
        index = std.array.length acc,
        value = e
    }] ) [] arr,
} in

{
    array = array',
}
