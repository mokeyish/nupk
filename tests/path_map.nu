use std/assert
use ../test.nu *
source ../nupk.nu


def "main test" [] {
    do test all $env.CURRENT_FILE [
        test_path_map
    ]
}

def test_path_map [] {
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