let { TestSuite, imports, .. } = import "base.ncl" in
let test_suite | TestSuite = import "_test_suite.ncl" in

m%"
pub const test_suite = %{imports.zig.zonify test_suite};
"%
