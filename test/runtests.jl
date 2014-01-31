using FactCheck
using DictFiles

macro throws_pred(ex) FactCheck.throws_pred(ex) end

filename = tempname()
data = [1 2 3 4 5]

facts("Helpers") do
    @fact DictFiles.sortkeys({}) => {}
    @fact DictFiles.sortkeys({3,2,1}) => {1,2,3}
    @fact DictFiles.sortkeys({3,2,"1"}) => {"1",2,3}
    @fact DictFiles.sortkeys({3,2,:a,"b"}) => {2,3,:a,"b"}
end

facts("Basic reading/writing to files") do
    dictopen(filename) do a
        @fact stat(filename).inode => not(0)

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

    dictopen(filename) do a
        @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
        @fact haskey(a, "a") => true
        @fact haskey(a, "z") => false

        @fact in("a",keys(a)) => true
        @fact in("b",keys(a)) => true
        @fact in(:c,keys(a)) => true
        @fact in(1,keys(a, "a")) => true
        @fact in(2,keys(a, "a")) => true

        a[(1,)] = 1
        @fact a[(1,)] => 1
        @fact in((1,),keys(a)) => true

        @fact in({1 => 11, 2 => 22},values(a)) => true
        @fact in(11,values(a,"a")) => true
        @fact in(22,values(a,"a")) => true
        @fact keys(a,"b") => {}
        @fact values(a,"b") => {}

        @fact get(a, 1, "a") => {1 => 11, 2 => 22}
        @fact get(a, 1, "z") => 1

        @fact getkey(a, 1, "a") => ("a",)
        @fact getkey(a, 1, "z") => 1
    end

    context("overwrite fields") do
        dictopen(filename,"w") do a
            a[1,1]   = "hi1"
            a[1]     = "hi2"
            a[1,2,1] = "hi3"
            a[1,2]   = "hi4"
            a[1,2,1] = "hi5"
            a[1]     = "hi6"
            a[1,2,1] = "hi7"
            a[1,3]   = "hi8"
        end
    end
end

facts("Compacting") do
    rm(filename)
    dictopen(filename) do a
        a["a"] = rand(1000,1000)
    end       
    oldsize = filesize(filename)
    dictopen(filename) do a
        a[] = {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
    end       
    compact(filename)
    dictopen(filename) do a
        @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
    end       
    @fact filesize(filename)<oldsize => true
end

facts("Error handling") do
    dictopen(filename) do a
        @fact a[] => {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}

        @fact @throws_pred(a["asdf"]) => (true, "error")
        @fact @throws_pred(a["a",123]) => (true, "error")
    end
end

facts("Tuple handling") do
    dictopen(filename) do a
        a["a","b",("ID", "param", 0, 0x5bca7c69b794f8ce)] = 123
        @fact a["a","b",("ID", "param", 0, 0x5bca7c69b794f8ce)] => 123
        @fact a["a"]["b"] => {("ID", "param", 0, 0x5bca7c69b794f8ce) => 123}
    end
end

@unix ? facts("Memory mapping") do
    dictopen(filename) do a
        data = rand(2,3)
        a["m"] = data
        m = mmap(a, "m") 
        @fact copy(m) => data
    end
end : nothing

facts("Subviews through DictFile(a, keys)") do
    rm(filename)
    dictopen(filename) do a
        a[] = {"a" => {1 => 11, 2 => 22}, "b" => data, :c => "c"}
        b = DictFile(a, "a")
        @fact keys(b) => {1,2}
        @fact values(b) => {11,22}
        b[3] = 33
        @fact b[3] => 33
        @fact a[] => {"a" => {1 => 11, 2 => 22, 3 => 33}, "b" => data, :c => "c"}
    end
end

facts("makekey(a, k)") do
    dictopen(filename) do a
        @fact DictFiles.makekey(a, (1,)) => "/1"
        @fact DictFiles.makekey(a, ('a',)) => "/'a'"
        @fact DictFiles.makekey(a, ("a",)) => "/\"a\""
        @fact DictFiles.makekey(a, (1,2)) => "/1/2"
        @fact DictFiles.makekey(a, (1,2,3,4,5)) => "/1/2/3/4/5"
        @fact DictFiles.makekey(a, (1,'a',3)) => "/1/'a'/3"
        @fact DictFiles.makekey(a, (1,'a',"a")) => "/1/'a'/\"a\""
        @fact DictFiles.makekey(a, ("abc",)) => "/\"abc\""
        @fact DictFiles.makekey(a, ("abc",(1,2))) => "/\"abc\"/(1,2)"
        @fact DictFiles.makekey(a, (1.,(1,2))) => "/1.0/(1,2)"
        @fact DictFiles.makekey(a, (1.f0,(1,2))) => "/1.0f0/(1,2)"
        @fact DictFiles.makekey(a, (1.f0,(1,2),"asdf",'b')) => "/1.0f0/(1,2)/\"asdf\"/'b'"
        @fact DictFiles.makekey(a, ([1,2,3],)) => "/[1,2,3]"
        @fact DictFiles.makekey(a, (1000,)) => "/1000"
    end
end

rm(filename)

facts("stress test") do
    nopen = 10
    nwrites = 200
    types = {Int32,Uint32,Int64,Uint64,Float32,Float64}
    payload() = rand(types[rand(1:length(types))], tuple(1,tuple(map( x -> rand(1:5), 5)...)...)...)

    filename = tempname()

    for iopen = 1:nopen
        data = cell(nwrites)
        readdata = cell(nwrites)
        dictopen(filename) do a
            for i = 1:nwrites
                key = map( x -> rand(1:10), 1:rand(1:3))
                data[i] = payload()
                a[key...] = data[i]
                readdata[i] = a[key...]
            end
        end
        @fact readdata  => data
    end

    DictFiles.compact(filename)

    rm(filename)
end











































