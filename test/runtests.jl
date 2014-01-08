using FactCheck
using DictFiles

macro throws_pred(ex) FactCheck.throws_pred(ex) end

facts("DictFiles core functions") do
    name = tempname()
    data = [1 2 3 4 5]

    context("Basic reading/writing to files") do
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
            a[:c] = "c"
            @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
        end

        dictopen(name) do a
            @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
            @fact haskey(a, "a") => true
            @fact haskey(a, "z") => false

            @fact in("a",keys(a)) => true
            @fact in("b",keys(a)) => true
            @fact in(:c,keys(a)) => true
            @fact in(1,keys(a, "a")) => true
            @fact in(2,keys(a, "a")) => true

            @fact in({1 => 11, 2 => 22},values(a)) => true
            @fact in(11,values(a,"a")) => true
            @fact in(22,values(a,"a")) => true
            @fact @throws_pred(values(a,"b")) => (true, "error")

            @fact get(a, 1, "a") => {1 => 11, 2 => 22}
            @fact get(a, 1, "z") => 1

            @fact getkey(a, 1, "a") => ("a",)
            @fact getkey(a, 1, "z") => 1
        end
    end

    context("Compacting") do
        rm(name)
        dictopen(name) do a
            a["a"] = rand(100,100)
            a[] = {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
        end       
        oldsize = filesize(name)
        compact(name)
        dictopen(name) do a
            @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
        end       
        @fact filesize(name)<oldsize => true
    end

    context("Error handling") do
        dictopen(name) do a
            @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}

            @fact @throws_pred(a["asdf"]) => (true, "error")
            @fact @throws_pred(a["a",123]) => (true, "error")
        end
    end

    context("Memory mapping") do
        dictopen(name) do a
            data = rand(2,3)
            a["m"] = data
            m = mmap(a, "m") 
            @fact copy(m) => data
        end
    end

    context("Subviews through DictFile(a, keys)") do
        rm(name)
        dictopen(name) do a
            a[] = {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
            b = DictFile(a, "a")
            @fact keys(b) => {1,2}
            @fact values(b) => {11,22}
            b[3] = 33
            @fact b[3] => 33
            @fact a[] => {"a" => {1 => 11, 2 => 22, 3 => 33}, "b" => data, :c => "c"}
        end
    end
    rm(name)

end








































