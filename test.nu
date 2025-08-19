#!/usr/bin/env nu
use std/log

const TEST_DIR = path self . | path join tests

export def "do test" [ work: closure, name: string ] {
    try {
        do $work
        log info  $"Test passed ✅: ($name)"
    } catch {
        log error $"Test failed ❌: ($name)"
    }
}


export def "do test all" [ file: string, unit_tests: list<string> ] {
    for unit_test in $unit_tests {
        do test {
            nu --commands $"source ($file); ($unit_test)"
        } $"($file)::($unit_test)"
    }
}


def main [
    --name(-n): string
] {
    let file_paths = if $name != null {
        $TEST_DIR | path join $"($name).nu"
    } else {
        ls $TEST_DIR  | where name =~ ".nu" | each { |it| $TEST_DIR | path join $it.name }
    }
    for file_path in $file_paths {
        try {
            ^($nu.current-exe) -n $file_path test
        } catch {
            log error $"Test failed ❌: ($name)"
        }
    }
}