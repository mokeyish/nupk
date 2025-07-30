#!/usr/bin/env nu
use std/log

const TEST_DIR = path self . | path join tests


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
            log info $"Test passed ✅: ($file_path)"
        } catch {
            log error $"Test failed ❌: ($file_path)"
        }
    }
}