let { Test, imports, .. } = import "_base.ncl" in
let test | Test = import "__test__.ncl" in

m%"
pub const @"test" = %{imports.zig.zonify test};
"%
