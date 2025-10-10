function cfr --description 'Compile and run'
    set name (basename $argv[1] .cpp)
    g++ -std=c++20 -O2 -Wall -Wextra -Wshadow -DLOCAL $argv[1] -o sol $argv[2..-1] && ./sol
end
