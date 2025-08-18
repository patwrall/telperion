function bak
    if [ (count $argv) -ne 1 ]
        echo "Usage: bak <file>"
        return 1
    end
    set original_file $argv[1]
    if not test -e $original_file
        echo "Error: File '$original_file' does not exist."
        return 1
    end
    set timestamp (date +%Y%m%d_%H%M%S)
    set backup_file "$original_file.$timestamp.bak"

    cp -a $original_file $backup_file
    echo "Created backup: '$backup_file'"
end
