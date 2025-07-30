source ../nupk.nu
use std/assert


def "main test" [] {
    let a = "bin/btop"
    let m = [
        {
            src: "bin/btop",
            dst: "bin"
        },
        {
            src: "themes",
            dst: "share/btop"
        }
    ]
    assert (("bin/btop" | path map-to $m) == "bin/btop")
    assert (("themes" | path map-to $m) == "share/btop/themes")
}