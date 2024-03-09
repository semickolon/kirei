let { Test, imports, .. } = import "_base.ncl" in
let test | Test = import "key_press.ncl" in

m%"
pub const @"test" = %{imports.zig.zonify test};
"%
