#!/usr/bin/env nu
use std/log

const THIS_DIR = path self .

def varables [ 
    --prefix: string
] {
    const NAME = "nupk"
    const OHMYNU = $nu.home-path | path join .ohmynu
    const PREFIX = $nu.home-path | path join .local
    const BIN_DIR = $PREFIX | path join bin
    const DATA_DIR = $nu.home-path | path join .config $NAME
    const DOWNLOAD_DIR = $nu.home-path | path join .cache $NAME

    let prefix = $prefix | default $env.NUPK_INSATLL_PREFIX? | default $PREFIX
    let data_dir = $env.NUPK_DATA_DIR? | default $DATA_DIR
    let download_dir = $env.NUPK_DOWNLOAD_DIR? | default $DOWNLOAD_DIR
    let installed_dir = $data_dir | path join "installed"
    let bin_dir = $prefix | path join bin

    let gh_proxy = $env.GH_PROXY?
    let gh_api = if $gh_proxy != null {
        $"($gh_proxy)/api.github.com"
    } else {
        "https://api.github.com"
    }

    mkdir $download_dir $installed_dir


    return {
        prefix: $prefix
        bin_dir: $bin_dir
        data_dir: $data_dir
        installed_dir: $installed_dir
        download_dir: $download_dir
        registry_dir: ($THIS_DIR | path join registry)
        gh_proxy: $gh_proxy
        gh_api: $gh_api
    }
}


# Eval code in a new shell instance
def eval [ ] {
    let code = $in
    ^($nu.current-exe) -n -c $"do { ($code) } | to nuon " | from nuon
}


def try-filter [
    predicate: closure,
] {
    let items = $in
    let length = $items | length
    let filtered = $items | where $predicate
    let filtered_length = $filtered | length

    if $filtered_length > 0 and $filtered_length < $length {
        return $filtered
    } else {
        return $items
    }
}


# Check if a directory is empty or contains only other empty directories.
def is-empty-dir [ ] {
    let dir = $in
    let entites = ls -af $dir
    if ($entites | length) == 0 {
        true
    } else if ($entites | any { |it| $it.type != "dir" } ) {
        false
    } else {
        $entites | each { |it| $it.name } | all { |it| $it | is-empty-dir }
    }
}

def "path map-to" [
    mappings: list<record<src: string, dst: string>>
] {
    let file_path = $in
    let mapping = $mappings | where { |it| $file_path | str starts-with $it.src } | first
    if $mapping == null {
        $file_path
    }
    let src = $mapping.src
    let dst = $mapping.dst
    let file_path = if $file_path == $src {
        $file_path | path basename
    } else {
        $file_path | path relative-to $src
    }
    $dst | path join $file_path
}


const STD_FHS_DIRS = [bin, sbin, lib, libexec, etc, share ]

# Is Filesystem Hierarchy Standard? (FHS) compliant?
def is-fhs [ ] {
    let dir = $in
    let entries = do {
        cd $dir
        ls -a 
    }
    if ($entries | any { |it| }) {
        return true
    }

    for entry in $entries {
        if $entry.type != "dir" {
            continue
        }
        if $entry.name == "bin" {
            return true
        }
        if $entry.name in ["usr", "local"] {
            let subdirs = do { cd ($dir | path join $entry.name); ls -a }
            for subdir in $subdirs {
                if $subdir.name in $STD_FHS_DIRS {
                    return true
                }
            }
        }
    }
    return false
}

def enter_single_non_fhs_dir [] {
    let src_dir = $in
    log debug $"changing src dir: ($src_dir)"
    if ($src_dir | is-fhs) {
        return $src_dir
    }

    let entries = ls $src_dir
    if ($entries | length) > 1 {
        return $src_dir
    }

    let entry = $entries | first
    if $entry.type != "dir" {
        return $src_dir
    }
    let src_dir = $src_dir | path join ($entry.name)
    log debug $"src dir changed: ($src_dir)"
    return ($src_dir | enter_single_non_fhs_dir)
}

def check-sum [
    digest: string
] {
    let file = $in
    if ($digest | str starts-with "sha256:") {
        (open $file | hash sha256) == ($digest | str substring 7..)
    } else if ($digest | str starts-with "md5:") {
        (open $file | hash md5) == ($digest | str substring 4..)
    } else {
        false
    }
}

def detect-target [] {
    return {
        "os": $nu.os-info.name
        "arch": $nu.os-info.arch
    }
}

def match-target [
    name: closure,
] {

    let items = $in | each {|it| { name: (do $name $it | str downcase), item: $it } }

    let target = detect-target
    let target_os = $target.os
    let target_arch = $target.arch


    let items = $items | where { |it| not ($it.name | str contains "sha256") }

    let items = $items | try-filter { |it| ($it.name | str contains $target_os) }
    let items = $items | try-filter { |it| ($it.name | match-arch ) }
    let items = $items | try-filter { |it| ($it.name | str contains "musl") }
    let items = $items | try-filter { |it| ($it.name | str ends-with ".tar.gz") }
    let items = $items | try-filter { |it| ($it.name | str ends-with ".tgz") }
    let items = $items | try-filter { |it| ($it.name | str ends-with ".zip")  }

    let items = $items | try-filter { |it| ($it.name | str ends-with "static")  }

    let items = $items | each { |it| $it.item }
    return $items
}

def match-arch [] {
    let text = $in
    let arch =  $nu.os-info.arch
    if ($text | str contains $arch) {
        return true
    }

    if ($text | str contains ($arch | str kebab-case)) {
        return true
    }

    if $arch == "x86_64" and (($text | str contains "amd64") or ($text | str contains "x64") ) {
        return true
    }
    return false
}

# check if a given file path points to an executable file or not. This function
# will return true if the given path points to an executable file, and false otherwise.
def is-executable [ ] {
    let file_path = $in
    # check if the file type is a regular file, also check if it exists
    if ($file_path | path type) != "file" {
        return false
    }

    # windows executable files end with .exe, we can directly return true here.
    if ($file_path | str ends-with ".exe") {
        return true
    }

    # get the file description using `file` command. This will tell us if it is
    # an executable or not. also, this will give us information about the
    # architecture of the binary.
    let file_desc = file $file_path

    # if the file description does not contain the word 'executable', then it
    # is not an executable.
    if not ($file_desc | str contains "executable") {
        return false
    }

    # check if the file is a script. If it is, then we can assume that it is executable.
    if ($file_desc | str contains "script") {
        return true
    }

    # check the architecture of the binary. If it matches the current
    # system's architecture, then we can assume that it is executable.
    if ($file_desc | match-arch) {
        return true
    }

    return false
}

def pkg [
    name: string
    --vars: record
] {
    let vars = $vars | default (varables)
    let candidate = if ($name | str contains "/") {
        let parts = $name | split row /
        if ($parts | length) != 2 {
            panic "Invalid package name format. Expected 'owner/name'."
        }
        ({ owner: ($parts | first), name: ($parts | last) })
    }
 
    use alias.nu alias
    let name = if $name in $alias {
        $alias | get $name
    } else {
        $name
    }
    let s = $vars.registry_dir | path join $"($name).nu"
    if not ($s | path exists) {
        if $candidate != null {
            return $candidate
        }
        if not ($name | str contains / ) {
            return { owner: $name, name: $name }
        }
        print $"($name) not found"
        exit 1
    }
    let info = $s | open | eval
    let info = if $info.commands? == null {
        $info | merge { commands: [ $name ] }
    } | default $info
    return $info
}

def release [
    name: string
    --version(-v): string = "latest"
    --vars: record
] {
    let vars = $vars | default (varables)
    let pkg = pkg $name
    let repo = if $pkg != null {
        $"($pkg.owner)/($pkg.name)"
    } else {
        $name
    }
    let url = $"($vars.gh_api)/repos/($repo)/releases/($version)"
    log debug $"Fetching release info from ($url)"
    let data = http get $url
    return $data
}

# check the exclude paths, if they are all in the install info's exclude paths,
# then use them directly. Otherwise, ask the user to select which ones to include.
def prompt-select [
    --prompt-message: string = "Please select:",
    --nothing-select-message: string,
    --selected: list<string>,
    --reverse
] {
    let options = $in

    if ($options | length) == 0 {
        return []
    }

    if $selected != null and ($options | all { |it| $it in $selected }) {
        return $options
    }

    log info $"($prompt_message)"
    let selected = $options | input list -m


    if ($selected | length) == 0 {
        if $nothing_select_message != null {
            log info $"($nothing_select_message)"
        }
        if $reverse {
            $options
        } else {
            []
        }
    } else {
        if $reverse {
            $options | where { |it| not ($it in $selected) }
        } else {
            $selected
        }
    }
}

def install-file [
    file_path: string,
    src_path: string,
    dst_path: string,
    --overwrite = false,
] {
    if ($dst_path | path exists) {
        let overwrite  = if not $overwrite {
            log info $"The ($dst_path) already exists, overwrite? "
            let answer = [ Yes, no] | input list
            $answer == "Yes"
        } else {
            $overwrite 
        }

        if $overwrite  {
            rm -f $dst_path
        } else {
            log info $"Skipping: ($file_path) to ($dst_path)"
            return false
        }
    }

    let dir = $dst_path | path dirname

    if not ($dir | path exists) {
        mkdir $dir
        log info $"Created directory: ($dir)"
    }

    cp -r $src_path $dst_path

    if ($dir | path basename) == "bin" {
        chmod +x $dst_path
    }
    log info $"Installed: ($file_path) to ($dst_path)"

    return true
}


def install [
    pkg: record
    src_dir: string
    dst_dir: string
    verion: string
    force: bool
    --vars: record
] {
    let vars = $vars | default (varables)
    log debug $"Installing ($pkg.name) from ($src_dir) to ($dst_dir)"
    
    log debug $"Installing ($pkg.name) from ($src_dir) to ($dst_dir)"

    let is_fhs = $src_dir | is-fhs
    let installed_dir = $vars.installed_dir

    let install_info_path = $installed_dir | path join $"($pkg.name).yaml"

    let install_info = if ($install_info_path | path exists) {
        $install_info_path | open
    } else {
        null
    }

    # list all files in the source directory.
    let file_paths = do {
        cd $src_dir
        ls -a **/* | each { |it| $it.name }
    }

    let file_count = $file_paths | length

    if $file_count == 0 {
        log info $"No files found in the source directory ($src_dir)"
        return null
    }

    log info $"Copying ($file_count) files to ($dst_dir)"

    let overwrite = $force


    # Case 0: pkg.install_paths is defined. Use it to install files to specific paths.
    if ($pkg.install_paths? != null and ($pkg.install_paths | columns | length) > 0) {
        log debug $"Case 0: pkg.install_paths is defined. Using it to install files to specific paths."

        let install_paths = $pkg.install_paths
        let install_path_mappings =    $install_paths 
            | columns 
            | sort-by -r { |x| ($x | path split | length)  } 
            | each { |x| { src: $x, dst: ($install_paths | get $x) } }



        let exclude_paths = $file_paths | where { |it| not ($install_path_mappings | any { |map| $it | str starts-with $map.src }) }

        # filter out the files that are in the exclude paths.
        let file_paths = if ($exclude_paths | length) > 0 {
            $file_paths | where { |it| not ( $it in $exclude_paths ) }
        } else {
            $file_paths
        }

        print ($install_path_mappings | to nuon)

        let installed_paths = $file_paths | each { | file_path |
            let src_path = $src_dir | path join $file_path
            let dst_path = do {
                cd $dst_dir
                $file_path | path map-to $install_path_mappings | path expand
            }

            if ($src_path | path type) != "dir" {
                log debug $"Installing file: ($src_path) -> ($dst_path)"
                install-file $file_path $src_path $dst_path --overwrite $overwrite
            }
            $dst_path
        }

        let install_info = {
            name: $pkg.name,
            installed_root: $dst_dir
            installed_date: (date now)
            installed_paths: $installed_paths
            exclude_paths: $exclude_paths
        }

        $install_info | to yaml | save -f $install_info_path

        return
    }

    # Case 1: FHS installation.
    if $is_fhs {
        log debug "Case 1: FHS installation."
        log info $"Starting FHS installation."
        # exclude non FHS directories and files from the installation process.
        let exclude_paths = do {
            cd $src_dir
            ls -a | where { |it| not ($it.name in $STD_FHS_DIRS) } | each { |it| $it.name }
        }

        let prompt_message = "The following are not Filesystem Hierarchy Standard(FHS), will be ignored, if you want to install them, please select them manually:"
        let nothing_select_message =  "Nothing selected, skipping installation of these files."

        let exclude_paths = $exclude_paths | prompt-select --reverse --selected $install_info.exclude_paths? --prompt-message $prompt_message --nothing-select-message $nothing_select_message

        # filter out the files that are in the exclude paths.
        let file_paths = if ($exclude_paths | length) > 0 {
            $file_paths | where { |it| not ($exclude_paths | any { |exclude_path| $it | str starts-with $exclude_path }) }
        } else {
            $file_paths
        }
        let installed_paths = $file_paths | each { |file_path|
            let src_path = $src_dir | path join $file_path
            let dst_path = $dst_dir | path join $file_path
            if ($src_path | path type) != "dir" {
                install-file $file_path $src_path $dst_path --overwrite $overwrite
            }
            $dst_path
        }

        let install_info = {
            name: $pkg.name,
            installed_root: $dst_dir
            installed_date: (date now)
            installed_paths: $installed_paths
            exclude_paths: $exclude_paths
        }

        $install_info | to yaml | save -f $install_info_path

        return
    }

    # Case 2: Single binary file installation (non-FHS)
    if $file_count == 1 {
        log debug "Case 2: Single binary file installation (non-FHS)"
        let file_path = $file_paths | first
        if ($file_path | path basename) != $file_path {
            log error "non-FHS binary binary file must be in the root directory of the source archive."
            exit 1 
        }
        let src_path = $src_dir | path join $file_path
        let dst_path = $dst_dir | path join bin $file_path # rename as command alias?

        install-file $file_path $src_path $dst_path --overwrite $overwrite

        let install_info = {
            name: $pkg.name,
            installed_root: $dst_dir
            installed_date: (date now)
            installed_paths: [$dst_path]
            exclude_paths: []
        }

        $install_info | to yaml | save -f $install_info_path

        return
    }

    let executables = do {
        cd $src_dir
        ls -a | each { |it| $it.name } | where { |it| $it | is-executable  }
    }

    # Case 3: all files are executables (non-FHS)
    if ($executables | length) == ($file_paths | length) {
        log debug "Case 3: all files are executables (non-FHS)"
        if ( $file_paths | any { |it| ($it | path basename) != $it  } ) {
            log error "A non-FHS binary file must be in the root directory of the source archive."
            exit 1 
        }

        let installed_paths = $file_paths | each { |file_path|
            let src_path = $src_dir | path join $file_path
            let dst_path = $dst_dir | path join bin $file_path
            install-file $file_path $src_path $dst_path --overwrite $overwrite
            $dst_path
        }

        let install_info = {
            name: $pkg.name,
            installed_root: $dst_dir
            installed_date: (date now)
            installed_paths: $installed_paths
            exclude_paths: []
        }

        $install_info | to yaml | save -f $install_info_path
        return
    }

    # Case 4: Other
    let exclude_paths = do {
        cd $src_dir
        ls -a | where { |it| not ($it.name in $executables) } | each { |it| $it.name }
    }

    print $"These executables will be installed to ($dst_dir)/bin:"
    print $executables

    let prompt_message = $"The following are not executables and will be ignored during installation, you can select them to install them to ($dst_dir) anyway:"
    let nothing_select_message =  "Nothing selected, skipping installation of these files."

    let exclude_paths = $exclude_paths | prompt-select --reverse --selected $install_info.exclude_paths? --prompt-message $prompt_message --nothing-select-message $nothing_select_message

    let file_paths = if ($exclude_paths | length) > 0 {
        $file_paths | where { |it| not ($exclude_paths | any { |exclude_path| $it | str starts-with $exclude_path }) }
    } else {
        $file_paths
    }

    let installed_paths = $file_paths | each { |file_path|
        let src_path = $src_dir | path join $file_path
        let dst_path = if $file_path in $executables  {
            $dst_dir | path join bin $file_path
        } else {
            $dst_dir | path join $file_path
        }
        if ($src_path | path type) != "dir" {
            install-file $file_path $src_path $dst_path --overwrite $overwrite
        }
        $dst_path
    }

    let install_info = {
        name: $pkg.name,
        installed_date: (date now)
        installed_root: $dst_dir
        installed_paths: $installed_paths
        exclude_paths: $exclude_paths
    }

    $install_info | to yaml | save -f $install_info_path
    return
}

def uninstall [
    name: string
    force: bool = false
    --vars: record
    --clear-install-info
] {
    let vars = $vars | default (varables)
    
    let installed_dir = $vars.installed_dir
    let install_info_path = $installed_dir | path join $"($name).yaml"
    if not ($install_info_path | path exists) {
        log warning $"($name) not installed by nupk"
        return
    }

    let install_info = $install_info_path | open

    let installed_paths = $install_info.installed_paths?
    if $installed_paths == null or ($installed_paths | length) == 0 {
        print $"($name) has no installed paths"
        return
    }

    let installed_dirs = $installed_paths | each { |file_path|
        if ($file_path | path exists) and ($file_path | path type) != "dir" {
            try { 
                rm $file_path
                print $"Uninstalled ($file_path)"
            } catch { 
                log error $"Failed to remove file: ($file_path)"
            }
        }
        if ($file_path | path type) == "dir" {
            $file_path
        } else {
            $file_path | path dirname
        }
    } | uniq | sort-by -r {|it|
        $it | path split | length
    } | where { |it|
        ($it | path exists) and ($it != $install_info.installed_root)
    }

    let reserved_dirs = $installed_dirs | where { |dir|
        if ($dir | is-empty-dir) {
            rm -r $dir
            log info $"Removed empty directory ($dir)"
            false
        } else if ( ($dir | path relative-to $install_info.installed_root) in $STD_FHS_DIRS) {
            false
        } else {
            true
        }
    }
    let fullly_uninstalled = ($reserved_dirs | length) == 0
    if not $fullly_uninstalled {
        log warning $"The following directories are not empty, reserved, you can remove them manually:"
        print $reserved_dirs
    }
    let clear_install_info = $clear_install_info and $fullly_uninstalled 
    if $clear_install_info {
        log debug $"Removing install info file ($install_info_path)"
        rm $install_info_path
        log debug $"Removed install info file ($install_info_path)"
    } else {
        $install_info | merge { status: "uninstalled" } | save -f $install_info_path
        log info $"Preserve install info file ($install_info_path)"
    }
    log info $"Uninstalled ($name)"
}


def list [
    --vars: record
] {
    let vars = $vars | default (varables)
    cd $vars.installed_dir
    ls -a | each { |it| $it.name } | each { |it| 
        $it | open
    }
}

def download [
    file_path: string
    download_url: string
    --file-digest: string
 ] {
    let file_name = $file_path | path basename
    let download_dir = $file_path | path dirname
    if ($file_path | path exists) and $file_digest != null and ($file_path | check-sum $file_digest) {
        print $"File already exists and matches the digest: ($file_name) to ($download_dir)"
    } else {
        print $"Downloading: ($file_name) to ($download_dir)"
        curl -o $file_path -L ($download_url)
        print $"Downloaded: ($file_name) to ($download_dir)"
        print $"Verifying the downloaded file: ($file_name) with digest: ($file_digest)"
        if ($file_digest != null) and not ($file_path | check-sum $file_digest) {
            print $"File digest mismatch for: ($file_name)"
            exit 1
        } else {
            print $"File verified successfully: ($file_name)"
        }
    }
}

def extract-tarball [
    file_path: string, 
    extract_dir: string
    bin_name: string
    mime_type: string = "application/x-tar"
] {
    let file_name = $file_path | path basename
    let ext1 = $file_name | path parse | get extension
    let ext2 = $file_name | path parse | get stem | path parse | get extension

    log debug $"File Name: ($file_name) with extensions: ($ext2) ($ext1)"

    print $"Extracting: ($file_name) to ($extract_dir)"

    match [$ext2, $ext1] {
        ["tar", "gz"] => {
            log debug $"Extracting .$($ext2).($ext1)"
            tar -xzvf $"($file_path)" -C $extract_dir
        }
        [_, "tgz"] => {
            log debug $"Extracting .($ext1)"
            tar -xzvf $"($file_path)" -C $extract_dir
        }
        [_, "tbz"] => {
            log debug $"Extracting .($ext1)"
            tar -xvf $file_path -C $extract_dir
        }
        ["tar", $ext ] if $ext != null => {
            log debug $"Extracting .$($ext2).($ext1)"
            tar -xvf $file_path -C $extract_dir
        }
        [_, "zip"] => {
            log debug $"Extracting .($ext1)"
            unzip -q $file_path -d $extract_dir
        },
        _ => {
            log debug $"Content Type: ($mime_type)"
            match $mime_type {
                "application/zip" => {
                    unzip -q $file_path -d $extract_dir
                },
                "application/x-tar" | "application/x-bzip1-compressed-tar" | "application/x-xz" => {
                    tar -xvf $file_path -C $extract_dir
                },
                "application/gzip" | "application/x-gzip" | "application/x-gtar" => {
                    tar -xzvf $"($file_path)" -C $extract_dir
                },
                "application/octet-stream" | "binary/octet-stream" | "raw" => {
                    cp $file_path ($extract_dir | path join $bin_name)
                },
                _ => {
                    if $ext1 == null {
                        cp $file_path ($extract_dir | path join $bin_name)
                    } else {
                        print $"Unsupported content type: ($mime_type)"
                        exit 1
                    }
                }
            }
        }
    }


    let extract_dir = $extract_dir | enter_single_non_fhs_dir

    do {
        cd $extract_dir
        let entries = ls
        if ($entries | length) == 1 {
            let entry = $entries | first
            if $entry.type == "file" and $entry.name != $bin_name {
                mv $entry.name $bin_name
            }
        }
    }

    print $"Extracted: ($file_name) to ($extract_dir)"

    $extract_dir
}

def install-package [
    name: string
    force: bool,
    yes: bool,
    --vars: record
] {
    let vars = $vars | default varables
    let prefix = $vars.prefix
    let bin_dir = $vars.bin_dir
    let target = detect-target

    log debug $"OS: ($target.os)"
    log debug $"Arch: ($target.arch)"

    # Rectify name for GitHub URLs
    let name = do {
        if ($name | str starts-with https://github.com/) {
            log debug "Rectifying name for GitHub URLs"
            let parts = $name | str substring 19.. | split row / | take 2
            if ($parts | length) != 2 {
                panic "Invalid GitHub URL format"
            }
            let owner = $parts | first
            let name = $parts | last
            let name = if ($name | str ends-with ".git") {
                $name | str substring ..-5
            } | default $name
            let name = $"($owner)/($name)"
            log debug $"Rectified name: ($name)"
            $name
        } | default $name
    }

    let name_parts = $name | split row "@"
    let name = $name_parts | first
    let version = $name_parts | get 1? | default latest

    log debug $"Name: ($name)"
    log debug $"Version: ($version)"

    let pkg = pkg $name
    if $pkg == null {
        print $"($name) not found"
        return
    }

    let bin_name = if $pkg.commands? != null and ($pkg.commands | length) > 0 {
        $pkg.commands | first
    } else {
        $pkg.name
    }
    let release = release -v $version $name --vars $vars
    let version = $release.name? | default ($release.tag_name) | str trim -l -c v
    log debug $"Version: ($version)"

    if not $force {
        let bin_path = $bin_dir | path join $bin_name
        let is_latest = try { 
            ($bin_path | path exists) and (^($bin_path) --version | str contains $version)
        } catch {
            false
        }
        if $is_latest {
            print $"($name) is already at the latest version: ($version)"
            return
        }
    }

    let assets = $release | get assets | match-target { |it| $it.name }
    if ($assets | length) == 0 {
        print $"No asset found for target: ($target)"
        return
    }
    let asset = match ($assets | length) {
        0 => {
            print "No asset found for target: ($target)"
            exit 1
        },
        1 => {
            $assets | first
        }
        _ => {
            print $"Multiple assets found for target: ($target), select one:"
            let idx = $assets | each { |it| $it.name } | input list --index
            let asset = $assets | get $idx
            print $"Selected asset: ($asset.name)"
            $asset
        }
    }

    try {
        let browser_download_url = $asset.browser_download_url
        let file_name = $asset.name
        let file_size = $asset.size
        let file_digest = $asset.digest?

        
        let work_dir = $vars.download_dir | path join $pkg.name $version
        let dist_dir = $work_dir | path join "dist"
        let file_path = $work_dir | path join $file_name

        let properties = {
            Name: $name
            Version: $version
            Size: ($file_size | into filesize)
            Digest: $file_digest
            "Download url": $browser_download_url
            "Release date": $release.published_at
            "Download destination": $file_path
            "Install prefix": $vars.prefix
        }
        print $properties

        if not $yes {
            print "Do you want to continue? "
            let confirm = ["Yes", "no"] | input list --index
            if $confirm == 1 {
                print "installing cancelled"
                exit 1
            }
        }

        if ($dist_dir | path exists) {
            rm -rf $dist_dir
        }
        mkdir $dist_dir

        download $file_path $browser_download_url --file-digest $file_digest

        let dist_dir = extract-tarball $file_path $dist_dir $bin_name ($asset.content_type?)

        install $pkg $dist_dir $prefix $version $force --vars $vars

        log info $"Installation of ($pkg.name) completed successfully."
    } catch { |err|
        print $"Error: ($err)"
    }

    log debug "Cleaning up temporary files..."
    # rm -rf $work_dir
    log debug "Cleanup complete."
}

def --wrapped main [
    --install(-i) # Install a package
    --uninstall(-u) # Uninstall a package
    --remove(-r) # Alias for uninstall
    --help(-h)
    ...args
] {
    if $install {
        ^($env.PROCESS_PATH) install ...$args
    } else if $uninstall or $remove {
        ^($env.PROCESS_PATH) uninstall ...$args
    } else if $help {
        help main
    } else {
        print (varables)
        print $"Type the `($env.PROCESS_PATH | path basename ) --help` to display help message "
    }
}

# List the installed packages
def "main list" [ 
    --name-only(-n)
    --all(-a)
] {
    let list = list | each { |it|
        { "name": $it.name, installed_date: $it.installed_date? }
    }
    if ($name_only) {
        for item in $list {
            print $item.name
        }
    } else {
        $list
    }
}

def "main show" [name: string] {
    release $name | to nuon
}

# Install a package by name and version.
def "main install" [
    --dest(-d): string
    --prefix(-p): string
    --force(-f),
    --yes(-y),
    ...pkgs: string
] {
    let vars = varables --prefix $prefix

    for name in $pkgs {
        install-package $name $force $yes --vars $vars
    }
}

# Uninstall a package by name
def "main uninstall" [
    ...pkgs: string
] {
    let vars = varables
    for name in $pkgs {
        let pkg = pkg $name
        if $pkg == null {
            print $"($pkg) not found"
            continue
        }
        uninstall $pkg.name --vars $vars --clear-install-info
    }
}

alias "main remove" = main uninstall

# Update package by name or all packages if no name is provided
def "main update" [
    --name: string
 ] {
}
def "main self update" [ ] {
    do {
        cd $THIS_DIR
        git pull --rebase --autostash
    }
}

def "main env" [
    name: string
] {
    let vars = varables
    with-env $vars {
        if $name != null {
            $env | get $name
        } else {
            $env
        }
    }
}

def --wrapped "main run" [ cmd: string, ...args ] {
    let vars = varables
    with-env {
        PATH: ($env.Path | prepend $vars.bin_dir)
    } {
        ^($cmd) ...$args
    }
}