use std/assert
use ../test.nu *
source ../nupk.nu


def "main test" [] {
    do test all $env.CURRENT_FILE [
        test_match_arch_1
        test_match_arch_2
        test_match_arch_3
        test_match_arch_reverse_1
        test_match_arch_reverse_2
        test_match_arch_reverse_3
        test_match_target_1
        test_match_os_1
    ]
}

def test_match_arch_1 [] {
    let items = [
        '64'
        arm64
    ]
    let ret = $items | where { |it| $it | match-arch -a aarch64 }
    assert (($ret | length) == 1)
    assert (($ret | get 0) == 'arm64')
}

def test_match_arch_2 [] {
    let items = [
        'x64'
        arm64
    ]
    let ret = $items | where { |it| $it | match-arch -a x86_64 }
    assert (($ret | length) == 1)
    assert (($ret | get 0) == 'x64')
}

def test_match_arch_3 [] {
    let items = [
        arm64
        x86-64
    ]
    let ret = $items | where { |it| $it | match-arch -a x86_64 }
    assert (($ret | length) == 1)
    assert (($ret | get 0) == 'x86-64')
}

def test_match_arch_reverse_1 [] {
    assert ("x86_64" | match-arch -a x86_64)

    assert not ("x86_64" | match-arch -a x86_64 -r)
    assert not ("64" | match-arch -a x86_64 -r)
    assert ("arm64" | match-arch -a x86_64 -r)
}

def test_match_arch_reverse_2 [] {
    let items = [
        '64'
        arm64
    ]
    let ret = $items | where { |it| not ($it | match-arch -a x86_64 -r) }
    assert (($ret | length) == 1)
    assert (($ret | get 0) == '64')
}

def test_match_arch_reverse_3 [] {
    let items = [
        '64'
        aarch64
    ]
    let ret = $items | where { |it| not ($it | match-arch -a x86_64 -r) }
    assert (($ret | length) == 1)
    assert (($ret | get 0) == '64')
}


def test_match_target_1 [] {
    let items = [
        '64'
        aarch64
    ]
    let ret = $items | match-target
    assert (($ret | length) == 1)
    assert (($ret | get 0) == '64')
}

def test_match_os_1 [] {
    let items = [
        '64'
        darwin
    ]
    let ret = $items | where { |it| $it | match-os -o macos }
    assert (($ret | length) == 1)
    assert (($ret | get 0) == 'darwin')
}