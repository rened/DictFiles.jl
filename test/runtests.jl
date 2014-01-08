module runtests

using FactCheck
using DictFiles

facts("DictFiles core functions") do

    context("Basic reading/writing to files") do
        data = [1 2 3 4 5]
        name = tempname()
        dictopen(name) do a
            @fact stat(name).inode => not(0)

            a["a"] = "aa"
            @fact a["a"] => "aa"
            @fact a[] => {"a"=>"aa"}
            a["a",1] = 11
            @fact a["a",1] => 11
            @fact a["a"] => {1 => 11}
            @fact a[] => {"a" => {1 => 11}}
            a["a",2] = 22
            @fact a["a",2] => 22
            @fact a["a"] => {1 => 11, 2 => 22}
            @fact a[] => {"a" => {1 => 11, 2 => 22}}
            a["b"] = data
            @fact a["b"] => data
            @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data}

            delete!(a, "a")
            @fact a[] => {"b" => data}

            delete!(a, "b")
            @fact a[] => Dict()

            a[] = {"a" => {1 => 11, 2 => 22}, "b" => data}
            @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data}
            a["a"] = {1 => 11, 2 => 22}
            @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data}
            a["a"] = "test"
            @fact a[] => {"a" => "test", "b" => data}
            a[:c] = "c"
            @fact a[] => {"a" => "test", "b" => data, :c => "c"}
        end
        dictopen(name) do a
            @fact a[] => {"a" => "test", "b" => data, :c => "c"}
            @fact haskey(a, "a") => true
            @fact haskey(a, "z") => false

            @fact get(a, 1, "a") => "test"
            @fact get(a, 1, "z") => 1

            @fact getkey(a, 1, "a") => ("a",)
            @fact getkey(a, 1, "z") => 1
        end
    end

#    context("Testing mmapping") do
#        name = tempname()
#        dictopen(name) do a
#            data = rand(100,200)
#            a["m"] = data
#            m = mmap(a, "m") 
#            @fact a => data
#        end
#    end

    context("Testing error handling") do
       # * check for non existing key error
    end

end

end







































