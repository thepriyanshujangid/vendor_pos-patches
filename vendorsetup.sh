#!/bin/bash

apply_patches() {
    local PATCHES_PATH="${ANDROID_BUILD_TOP}/vendor/pos-patches/patches"
    
    # Exit if patches directory doesn't exist
    [[ ! -d "$PATCHES_PATH" ]] && return 0
    
    local failed=false
    local PATCHED_DIRS=()
    
    # Process each project directory
    while IFS= read -r -d '' project_dir; do
        local project_name=$(basename "$project_dir")
        local project_path=$(echo "$project_name" | tr '_' '/')
        local full_project_path="${ANDROID_BUILD_TOP}/${project_path}"
        
        # Skip if project doesn't exist
        [[ ! -d "$full_project_path" ]] && {
            echo -e "\e[33m[WARNING]\e[0m Skipping $project_path (path not found)"
            continue
        }
        
        # Change to project directory
        pushd "$full_project_path" >/dev/null || continue
        
        echo -e "\e[32m[INFO]\e[0m Checking patches for $project_path"
        shopt -s nullglob
        
        local any_patch_applied=false
        for patch_file in "$project_dir"/*.patch; do
            local patch_name=$(basename "$patch_file")
            
            echo -e "\e[34m[CHECK]\e[0m Testing $patch_name"
            
            # Dry-run check - no source modification
            if ! git apply --check --3way --ignore-whitespace "$patch_file" 2>/dev/null; then
                echo -e "\e[31m[FAILED]\e[0m $patch_name does not apply cleanly. Skipping project."
                failed=true
                break
            fi
            
            echo -e "\e[34m[APPLY]\e[0m Applying $patch_name"
            if git am --no-gpg-sign --3way --ignore-whitespace "$patch_file"; then
                echo -e "\e[32m[SUCCESS]\e[0m Applied $patch_name"
                any_patch_applied=true
            else
                echo -e "\e[31m[ERROR]\e[0m Failed to apply $patch_name. Aborting."
                git am --abort &>/dev/null
                failed=true
                break
            fi
        done
        
        popd >/dev/null
        
        # Track successfully patched directories
        [[ "$any_patch_applied" == true ]] && PATCHED_DIRS+=("$full_project_path")
        
    done < <(find "$PATCHES_PATH" -mindepth 1 -maxdepth 1 -type d -print0)
    
    # Report summary
    if [[ "${#PATCHED_DIRS[@]}" -gt 0 ]]; then
        echo -e "\e[32m[SUCCESS]\e[0m Patched ${#PATCHED_DIRS[@]} projects:"
        printf '  - %s\n' "${PATCHED_DIRS[@]}"
    fi
    
    [[ "$failed" == true ]] && {
        echo -e "\e[31m[FAILED]\e[0m Some patches failed. Source remains clean."
        return 1
    }
    
    echo -e "\e[32m[SUCCESS]\e[0m All patches applied cleanly!"
    return 0
}

# Execute
apply_patches "$@"
